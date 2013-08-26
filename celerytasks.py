import re
import config
import pickle
import requests
import celeryconfig
import logging
import time
from redis import Redis
from celery import Celery, chain, group
from celery.task.sets import TaskSet

## Logging output formatting
config.configure_logging()

## Redis
INCOMPLETE_TASKS = '__incomplete_tasks'
COMPLETED_TASKS = '__completed_tasks'
redis = Redis(config.REDIS_HOSTNAME)

if redis.exists(INCOMPLETE_TASKS):
    redis.delete(INCOMPLETE_TASKS)

if redis.exists(COMPLETED_TASKS):
    redis.delete(COMPLETED_TASKS)

## Load probe URLs
logging.info('Loading list of probe URLs from file')
probe_urls = pickle.load(open('probe_urls.p', 'rb'))

## Celery
celery = Celery('celerytasks')
celery.config_from_object(celeryconfig)

## Set pool bounds
pool_size = 100
for i in xrange(1, int(len(probe_urls)/pool_size)):
    redis.sadd(INCOMPLETE_TASKS, i)

scrape_urls = []
@celery.task(name='get_scrape_url')
def get_scrape_url(url):
    global scrape_urls
    def extract_scrape_url(r):
        app_id = int(extract_single_value('.*?/id=([0-9]+)/.*$', r.url))
        if r.status_code != 200:
            logging.warning('Status was {0} for appID {1}'.format(r.status_code, app_id))
            return
        feed = parse_feed(r.json())
        page_url = [x for x in feed['link'] if x['attributes']['rel'] == 'last'][-1]['attributes']['href']
        num_pages = 1
        if len(page_url) > 0:
            num_pages = int(extract_single_value('.*?/page=([0-9]+)/.*$', page_url))
        for i in xrange(1, num_pages+1):
            scrape_urls.append(config.REVIEWS_URL.format(i, app_id))

    logging.info('Getting: {0}'.format(url))
    return 'OK'
#    r = requests.get(probe_urls[k])
#    extract_scrape_url(r)

#	logging.info('Dumping scrape URLs to file'.format(len(scrape_urls)))
#	pickle.dump(scrape_urls, open('scrape_urls.p', 'wb'))


@celery.task(name='push_scrape_tasks')
def push_scrape_tasks():
    global probe_urls, scrape_urls, pool_size
    num_tasks = int(len(probe_urls)/pool_size)
    task_index = redis.spop(INCOMPLETE_TASKS)
    if task_index is not None:
        task_index = int(task_index)
    j = task_index*pool_size
    i = j-pool_size
    logging.info('Getting scrape URLs from range {0} to {1}'.format(i,j))
#    g = group(get_scrape_url.s(url) for url in probe_urls[i:j])()
#    logging.info('Result: {0}'.format(g.get()))



