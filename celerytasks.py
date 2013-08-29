import re
import os
import gc
import json
import socket
import config
import pickle
import urllib2
import celeryconfig
import logging
import time
from celery.exceptions import RetryTaskError
from pprint import pprint
from lxml import etree
from pymongo import MongoClient
from redis import Redis
from celery import Celery, task, chord, chain, current_task


## MongoDB
mc = MongoClient(config.MONGO_CONNECTION_STRING)
db = mc[config.MONGO_DB]

## Celery
celery = Celery('celerytasks')
celery.config_from_object(celeryconfig)

## Logging output formatting
config.configure_logging()

## Redis
APP_IDS = '__app_ids'
TOTAL_APP_IDS = '__total_app_ids'
redis = Redis(config.REDIS_HOSTNAME)

## Set pool bounds
pool_size = 50
format = 'xml'

## Garbage collector
gc.enable()

ERRORS = {
    'UNKNOWN': -1,
    'RETRY': 0,
    'HTTP': 1,
    'FEED': 2,
    'MONGO': 3
}


@task(name='remaining_app_ids')
def remaining_app_ids():
    return redis.scard(APP_IDS)


@task(name='scrape_review', max_retries=3, default_retry_delay=10, rate_limit='{0}/s'.format(pool_size))
def scrape_review(app_id, *args, **kwargs):
    global format
    if format == 'xml':
        format = 'json'
    else:
        format = 'xml'

    def get_feed(page_num, app_id, format='xml'):
        try:
            logging.warning('[{0}]  Requesting {1}'.format(current_task.request.id, config.REVIEWS_URL.format(page_num, app_id, format)))
            r = urllib2.urlopen(config.REVIEWS_URL.format(page_num, app_id, format))
        except urllib2.HTTPError as ex:
            logging.warning('[{0}]  Status code was {1}. Retrying...'.format(current_task.request.id, ex.code))
            raise scrape_review.retry(exc=ex)
        except urllib2.URLError as ex:
            logging.warning('[{0}]  Unknown URLError: {1}. Retrying...'.format(current_task.request.id, ex.message))
            raise scrape_review.retry(exc=ex)

        if format == 'xml':
            try:
                return etree.parse(r)
            except Exception as ex:
                logging.warning('[{0}]  Unknown XML parse error: {1}. Retrying...'.format(current_task.request.id, ex.message))
                raise scrape_review.retry(exc=ex)
        else:
            try:
                f = json.loads(unicode(r.read(), 'utf-8'))
                return f['feed']
            except Exception as ex:
                logging.warning('[{0}]  Unknown JSON parse error: {1}. Retrying...'.format(current_task.request.id, ex.message))
                raise scrape_review.retry(exc=ex)

    def extract_single_value(regex, data):
        match = re.match(regex, data)
        if match is None:
            logging.warning('Unable to extract data using regex /{0}/ for data `{1}`'.format(regex, data))
            return None
        return match.group(1)

    def extract_review(feed, format='xml'):
        reviews = []
        if format == 'xml':
            for entry in feed.findall('.//{http://www.w3.org/2005/Atom}entry'):
                review_node = entry.find('./{http://www.w3.org/2005/Atom}content[@type="text"]')
                if review_node is not None:
                    reviews.append({
                        'author_id': int(entry.find('./{http://www.w3.org/2005/Atom}id').text),
                        'author': entry.find('./{http://www.w3.org/2005/Atom}author/{http://www.w3.org/2005/Atom}name').text,
                        'review': review_node.text,
                        'rating': int(entry.find('./{http://itunes.apple.com/rss}rating').text)
                    })
        else:
            if 'entry' in feed:
                for entry in feed['entry']:
                    if 'author' not in entry:
                        continue
                    author_id = extract_single_value('.*?/id([0-9]+)$', entry['author']['uri']['label'])
                    if author_id is not None:
                        author_id = int(author_id)
                    else:
                        author_id = -1
                    reviews.append({
                        'author_id': author_id,
                        'author': entry['author']['name']['label'],
                        'review': entry['content']['label'],
                        'rating': int(entry['im:rating']['label'])
                    })
        return reviews

    num_pages = 1
    reviews = []
    if app_id is None:
        return
    logging.info('[{0}]  Extracting reviews from page 1'.format(app_id))

    feed = None
    try:
        feed = get_feed(1, app_id, format)
    except RetryTaskError as ex:
        logging.warning('[RetryTaskError]  Could not scrape appID {0}'.format(app_id))
        raise ex
    except urllib2.HTTPError as ex:
        logging.warning('[HTTPError]  Could not scrape appID {0}'.format(app_id))
        return {'error': {'HTTPError': {'code': ex.code, 'reason': ex.reason}}, 'error_code': ERRORS['HTTP']}
    except Exception as ex:
        logging.warning('[Exception]  Could not scrape appID {0}'.format(app_id))
        return {'error': repr(ex), 'error_code': ERRORS['UNKNOWN']}

    if format == 'xml':
        num_pages = feed.find('.//{http://www.w3.org/2005/Atom}link[@rel="last"]')
        if num_pages is not None and 'href' in num_pages.attrib:
            num_pages = extract_single_value('.*?/page=?([0-9]+)/?.*$', num_pages.attrib['href'])
    else:
        link = [link for link in feed['link'] if link['attributes']['rel'] == 'last']
        if len(link) > 0:
            link = link[-1]
            if 'attributes' in link:
                if 'href' in link['attributes']:
                    num_pages = extract_single_value('.*?/page=?([0-9]+)/?.*$', link['attributes']['href'])

    if num_pages is None:
        num_pages = 1
    else:
        num_pages = int(num_pages)

    reviews.extend(extract_review(feed, format))
    if num_pages > 1:
        for i in xrange(2, num_pages+1):
            logging.info('[{0}]  Extracting reviews from page {1}'.format(app_id, i))
            try:
                feed = get_feed(i, app_id, format)
                if feed is not None:
                    reviews.extend(extract_review(feed, format))
            except Exception as ex:
                logging.warning('Could not scrape appID {0}'.format(app_id))
                return {'error': ex.message, 'error_code': ERRORS['FEED']}

    doc = db['app_data'].find_one({'app_id': app_id})
    if doc is None:
        logging.warning('Could not find document in database for appID {0}'.format(app_id))
        return {'error': 'Mongo document not found for appID {0}'.format(app_id), 'error_code': ERRORS['MONGO']}
    else:
        if len(reviews) > 0:
            doc['reviews'] =  reviews
        _id = db['app_data'].save(doc, w=1)
        logging.info('Saved {0}'.format(_id))
    return 'OK'

@task(name='push_scrape_tasks')
def push_scrape_tasks(subtask_results=None, rate_limit='30/m'):
    global pool_size

    '''
    if subtask_results is not None:
        for x in subtask_results:
            if 'error_code' in x:
                pprint('Subtask results {0}'.format(x))
                if x['error_code'] == ERRORS['RETRY']:
                    return
    '''

    to_scrape = []
    for i in xrange(0, pool_size):
        s_app_id = redis.spop(APP_IDS)
        if s_app_id is not None:
            to_scrape.append(int(s_app_id))
    l = redis.scard(APP_IDS)
    logging.info('------------> Progress: {0}/{1}  {2:.2f}%'.format(l, redis.srandmember(TOTAL_APP_IDS), 100.0 - 100.0*(float(l)/float(redis.srandmember(TOTAL_APP_IDS)))))
    if len(to_scrape) == 0:
        logging.info('Done')
    else:
        chord(scrape_review.s(app_id) for app_id in to_scrape)(push_scrape_tasks.s())

@task(name='initialize')
def initialize():
    app_ids = set()
    logging.info('Initializing...')
    if os.path.exists('app_ids.p'):
        logging.info('Loading appIDs from file')
        app_ids = pickle.load(open('app_ids.p', 'rb'))
    else:
        docs = db['app_data'].find({'reviews':{'$exists':0}}, timeout=False)
        total = docs.count()
        i = -1
        for doc in docs:
            i += 1
            app_ids.add(doc['app_id'])
            logging.info('{0:.2f}%'.format(100.0*i/total))
        logging.info('Writing appIDs to file')
        pickle.dump(app_ids, open('app_ids.p', 'wb'))
    logging.info('Done. Got {0} appIDs to scrape'.format(len(app_ids)))
    if redis.exists(APP_IDS):
        logging.info('Checking Redis appID cache')
        if redis.scard(APP_IDS) != len(app_ids):
            logging.warning('Reseting Redis appID cache')
            redis.delete(APP_IDS)
            redis.sadd(APP_IDS, *app_ids)
        else:
            logging.info('Reusing Redis appID cache')
    else:
        logging.info('Building Redis appID cache')
        redis.sadd(APP_IDS, *app_ids)
    redis.sadd(TOTAL_APP_IDS, redis.scard(APP_IDS))
    logging.info('There are {0} appIDs in Redis'.format(redis.srandmember(TOTAL_APP_IDS)))

if socket.gethostname() in config.INIT_HOSTS:
    (initialize.s() | push_scrape_tasks.s())()
    

