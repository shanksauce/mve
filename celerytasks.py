import re
import os
import config
import pickle
import requests
import celeryconfig
import logging
import time
import elementtree.ElementTree as ET
from pymongo import MongoClient
from redis import Redis
from celery import Celery, chain, group, chord, current_task, states, task

## MongoDB
mc = MongoClient(config.MONGO_CONNECTION_STRING)
db = mc[config.MONGO_DB]

## Celery
celery = Celery('celerytasks')
celery.config_from_object(celeryconfig)

## Logging output formatting
config.configure_logging()

## Redis
SCRAPE_URLS = '__scrape_urls'
INCOMPLETE_TASKS = '__incomplete_tasks'
redis = Redis(config.REDIS_HOSTNAME)
redis.delete(INCOMPLETE_TASKS)
redis.delete(SCRAPE_URLS)

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

## Set pool bounds
pool_size = 25
for i in xrange(1, int(len(app_ids)/pool_size)):
    redis.sadd(INCOMPLETE_TASKS, i)

exit()

def parse_feed(feed):
    if 'feed' not in feed:
        raise Exception('The feed seems to be messed up. Here\'s the raw JSON:\n%s ' % r.text)
    return feed['feed']

def extract_single_value(regex, data):
    match = re.match(regex, data)
    if match is None:
        logging.warning('Unable to extract data using regex /{0}/ for data `{1}`'.format(regex, data))
        return None
    return match.group(1)

@task(name='get_scrape_url')
def get_scrape_url(url):
    r = requests.get(url)

    parse(urllib.urlopen(url)).getroot()

    app_id = int(extract_single_value('.*?/id=([0-9]+)/.*$', r.url))
    num_pages = 1
    if r.status_code != 200:
        logging.warning('Status was {0} for appID {1}'.format(r.status_code, app_id))
        redis.sadd(SCRAPE_URLS, {'app_id': app_id, 'num_pages': 1})
    else:
        feed = parse_feed(r.json())
        page_url = [x for x in feed['link'] if x['attributes']['rel'] == 'last'][-1]['attributes']['href']
        if len(page_url) > 0:
            num_pages = int(extract_single_value('.*?/page=([0-9]+)/.*$', page_url))
        logging.info('Got {0} pages'.format(num_pages))
        for i in xrange(1, num_pages+1):
            redis.sadd(SCRAPE_URLS, {'app_id': app_id, 'num_pages': 1})
        logging.info('Now have {0} scrape URLs'.format(redis.scard(SCRAPE_URLS)))
    return {'app_id': app_id, 'status': r.status_code, 'num_pages': num_pages}

@task(name='push_scrape_tasks', ignore_result=True)
def push_scrape_tasks(task_id=None):
    global app_ids, pool_size
    num_tasks = int(len(app_ids)/pool_size)
    task_index = redis.spop(INCOMPLETE_TASKS)
    if task_index is None:
        if not os.path.exists('scrape_urls.p'):
            logging.info('Dumping scrape URLs to file'.format(redis.scard(SCRAPE_URLS)))
            pickle.dump(redis.smembers(SCRAPE_URLS), open('scrape_urls.p', 'wb'))
        return 'DONE'
    task_index = int(task_index)
    j = task_index*pool_size
    i = j-pool_size
    logging.info('Getting scrape URLs from range {0} to {1}'.format(i,j))
    g = chord(get_scrape_url.s(url) for url in probe_urls[i:j])(push_scrape_tasks.s())

push_scrape_tasks.delay()

