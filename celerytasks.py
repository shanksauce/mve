import re
import config
import pickle
import requests
import celeryconfig
import logging
import time
from redis import Redis
from celery import Celery, chain, group, chord
from celery.task.sets import TaskSet

## Logging output formatting
config.configure_logging()

## Load probe URLs
logging.info('Loading list of probe URLs from file')
probe_urls = pickle.load(open('probe_urls.p', 'rb'))

## Celery
celery = Celery('celerytasks')
celery.config_from_object(celeryconfig)

## Redis
SCRAPE_URLS = '__scrape_urls'
INCOMPLETE_TASKS = '__incomplete_tasks'
COMPLETED_TASKS = '__completed_tasks'
redis = Redis(config.REDIS_HOSTNAME)
if redis.exists(INCOMPLETE_TASKS):
    redis.delete(INCOMPLETE_TASKS)
if redis.exists(COMPLETED_TASKS):
    redis.delete(COMPLETED_TASKS)
if redis.exists(SCRAPE_URLS):
    redis.delete(SCRAPE_URLS)

## Set pool bounds
pool_size = 25
for i in xrange(1, int(len(probe_urls)/pool_size)):
    redis.sadd(INCOMPLETE_TASKS, i)

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

@celery.task(name='get_scrape_url')
def get_scrape_url(url):
    r = requests.get(url)
    app_id = int(extract_single_value('.*?/id=([0-9]+)/.*$', r.url))
    if r.status_code != 200:
        logging.warning('Status was {0} for appID {1}'.format(r.status_code, app_id))
        return
    feed = parse_feed(r.json())
    page_url = [x for x in feed['link'] if x['attributes']['rel'] == 'last'][-1]['attributes']['href']
    num_pages = 1
    if len(page_url) > 0:
        num_pages = int(extract_single_value('.*?/page=([0-9]+)/.*$', page_url))
    logging.info('Got {0} pages'.format(num_pages))
    for i in xrange(1, num_pages+1):
        redis.sadd(SCRAPE_URLS, config.REVIEWS_URL.format(i, app_id))
    logging.info('Now have {0} scrape URLs'.format(redis.scard(SCRAPE_URLS))

@celery.task(name='push_scrape_tasks')
def push_scrape_tasks(task_id=None):
    global probe_urls, pool_size
    config.configure_logging()
    num_tasks = int(len(probe_urls)/pool_size)
    task_index = redis.spop(INCOMPLETE_TASKS)
    if task_index is None:
        if not os.path.exists('scrape_urls.p'):
            logging.info('Dumping scrape URLs to file'.format(redis.scard(SCRAPE_URLS))
            pickle.dump(redis.smembers(SCRAPE_URLS), open('scrape_urls.p', 'wb'))
        return 'DONE'
    task_index = int(task_index)
    j = task_index*pool_size
    i = j-pool_size

    logging.info('Getting scrape URLs from range {0} to {1}'.format(i,j))
    g = chord(get_scrape_url.s(url) for url in probe_urls[i:j])(push_scrape_tasks.s())



