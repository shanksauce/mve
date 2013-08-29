import re
import os
import gc
import socket
import config
import pickle
import requests
import celeryconfig
import logging
import time
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
pool_size = 10

gc.enable()

@task(name='scrape_review')
def scrape_review(app_id, *args, **kwargs):
    def get_feed(page_num, app_id):
        r = requests.get(config.REVIEWS_URL.format(page_num, app_id))
        r.encoding = 'UTF-8'
        if r.status_code != 200:
            raise Exception('Status code was: {0}'.format(r.status_code))
        else:
            if r.content is None:
                raise Exception('No response text: {0}'.format(r.content))
            else:
                return etree.fromstring(r.content)

    def extract_single_value(regex, data):
        match = re.match(regex, data)
        if match is None:
            logging.warning('Unable to extract data using regex /{0}/ for data `{1}`'.format(regex, data))
            return None
        return match.group(1)

    def extract_review(feed):
        reviews = []
        for entry in feed.findall('.//{http://www.w3.org/2005/Atom}entry'):
            review_node = entry.find('./{http://www.w3.org/2005/Atom}content[@type="text"]')
            if review_node is not None:
                reviews.append({
                    'author_id': int(entry.find('./{http://www.w3.org/2005/Atom}id').text),
                    'author': entry.find('./{http://www.w3.org/2005/Atom}author/{http://www.w3.org/2005/Atom}name').text,
                    'review': review_node.text,
                    'rating': int(entry.find('./{http://itunes.apple.com/rss}rating').text)
                })
        return reviews

    num_pages = 1
    reviews = []
    if app_id is None:
        return
    logging.info('Extracting reviews from page 1')

    feed = None
    try:
        feed = get_feed(1, app_id)
    except Exception as ex:
        logging.warning('Could not scrape appID {0}'.format(app_id))
        return {'error': ex.message}

    num_pages = feed.find('.//{http://www.w3.org/2005/Atom}link[@rel="last"]')
    if num_pages is not None and 'href' in num_pages.attrib:
        num_pages = extract_single_value('.*?/page=?([0-9]+)/?.*$', num_pages.attrib['href'])
        if num_pages is None:
            num_pages = 1
        else:
            num_pages = int(num_pages)

    reviews.extend(extract_review(feed))
    if num_pages > 1:
        for i in xrange(2, num_pages+1):
            logging.info('Extracting reviews from page {0}'.format(i))
            feed = get_feed(i, app_id)
            if feed is not None:
                reviews.extend(extract_review(feed))

    doc = db['app_data'].find_one({'app_id': app_id})
    if doc is None:
        logging.warning('Could not find document in database for appID {0}'.format(app_id))
        return {'error': 'Mongo document not found for appID {0}'.format(app_id)}
    else:
        if len(reviews) > 0:
            doc['reviews'] =  reviews
        _id = db['app_data'].save(doc, w=1)
        logging.info('Saved {0}'.format(_id))
    return 'OK'

@task(name='push_scrape_tasks', ignore_result=True)
def push_scrape_tasks(task_id=None):
    global pool_size
    to_scrape = []
    for i in xrange(0, pool_size):
        s_app_id = redis.spop(APP_IDS)
        if s_app_id is not None:
            to_scrape.append(int(s_app_id))
    l = redis.scard(APP_IDS)
    logging.info('------------> Progress: {0}/{1}  {2:.2f}%'.format(l, redis.srandmember(TOTAL_APP_IDS), 100.0*(l/int(redis.srandmember(TOTAL_APP_IDS)))))
    if len(to_scrape) == 0:
        logging.info('Done')
    else:
        g = chord(scrape_review.s(app_id) for app_id in to_scrape)(push_scrape_tasks.s())

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

logging.info('I am {0}'.format(socket.gethostname()))

if socket.gethostname() in config.INIT_HOSTS:
    (initialize.s() | push_scrape_tasks.s())()
    



