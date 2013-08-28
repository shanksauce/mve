import re
import os
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
from celery import Celery, task, chord, current_task

## MongoDB
mc = MongoClient(config.MONGO_CONNECTION_STRING)
db = mc[config.MONGO_DB]

## Celery
celery = Celery('celerytasks')
celery.config_from_object(celeryconfig)

## Logging output formatting
config.configure_logging()

## Cache appIDs
app_ids = set()
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

## Redis
APP_IDS = '__app_ids'
redis = Redis(config.REDIS_HOSTNAME)
redis.delete(APP_IDS)
redis.sadd(APP_IDS, *app_ids)

## Set pool bounds
total_app_ids = redis.scard(APP_IDS)
pool_size = 10

@task(name='scrape_review')
def scrape_review(app_id, *args, **kwargs):
    def get_feed(page_num, app_id):
        time.sleep(0.1)
        r = requests.get(config.REVIEWS_URL.format(page_num, app_id))
        if r.status_code != 200:
            logging.warning('************ Status code was: {0}'.format(r.status_code))
            return None
        else:
            if r.content is None:
                logging.warning('************ No response text: {0}'.format(r.text))
                return None
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
    feed = get_feed(1, app_id)
    if feed is None:
        logging.warning('Could not scrape appID {0}'.format(app_id))
        return 'E_SCRAPE_FAILED'
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
        return 'E_DOCUMENT_NOT_FOUND'
    else:
        if len(reviews) > 0:
            doc['reviews'] =  reviews
        _id = db['app_data'].save(doc, w=1)
        logging.info('Saved {0}'.format(_id))
    return 'E_OK'

@task(name='push_scrape_tasks', ignore_result=True)
def push_scrape_tasks(task_id=None):
    global total_app_ids, pool_size
    to_scrape = []
    for i in xrange(0, pool_size):
        to_scrape.append(int(redis.spop(APP_IDS)))
    l = redis.scard(APP_IDS)
    logging.info('------------> Progress: {0}/{1}  {2:.2f}%'.format(l, total_app_ids, 100.0*(l/total_app_ids)))
    if len(to_scrape) == 0:
        logging.info('Done')
    else:
        g = chord(scrape_review.si(app_id) for app_id in to_scrape)(push_scrape_tasks.si())

push_scrape_tasks.delay()








