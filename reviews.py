#!/usr/bin/env python
import re
import os
import sys
import logging
import requests
from pymongo import MongoClient
from pprint import pprint

os.system('clear')
logging.basicConfig(format='[ %(levelname)s ] @ %(lineno)d: %(message)s', level=logging.INFO)

RSS_URL = 'http://itunes.apple.com/rss/customerreviews/id={0}/json'
REVIEWS_URL = 'http://itunes.apple.com/us/rss/customerreviews/page={0}/id={1}/sortby=mostrecent/json'
MONGO_DB = 'app'
MONGO_CONNECTION_STRING = 'mongodb://localhost/%s' % MONGO_DB

mc = MongoClient(MONGO_CONNECTION_STRING)
db = mc[MONGO_DB]

def parse_feed(feed):
	if 'feed' not in feed:
		raise Exception('The feed seems to be messed up. Here\'s the raw JSON:\n%s ' % r.text)
	return feed['feed']

def extract_single_value(regex, data):
	match = re.match(regex, data)
	if match is None:
		raise Exception('Unable to extract data using regex {0} for data {1}'.format(regex, data))
	return match.group(1)

try:
	for doc in db['app_data'].find():
		app_id = doc['app_id']
		logging.info('Probing {0}'.format(RSS_URL.format(app_id)))
		r = requests.get(RSS_URL.format(app_id))
		feed = parse_feed(r.json())

		print feed['link']
		exit()

		page_url = [x for x in feed['link'] if x['attributes']['rel'] == 'last'][-1]['attributes']['href']
		num_pages = int(extract_single_value('.*?/page=([0-9]+)/.*$', page_url))
		logging.info('Got {0} pages'.format(num_pages))
		reviews = []
		for i in xrange(1, num_pages+1):
			r = requests.get(REVIEWS_URL.format(i, app_id))
			feed = parse_feed(r.json())
			for raw_review in feed['entry']:
				if 'rights' in raw_review:
					continue
				author_id = int(extract_single_value('.*?/id([0-9]+)', raw_review['author']['uri']['label']))
				review = {
					'id': int(raw_review['id']['label']),
					'app_version_id': raw_review['im:version']['label'],
					'author_id': author_id,
					'author_name': raw_review['author']['name']['label'],
					'rating': int(raw_review['im:rating']['label']),
					'title': raw_review['title']['label'],
					'content': raw_review['content']['label']
				}
				reviews.append(review)
		doc['reviews'] = reviews
		db['app_data'].save(doc, w=1)
	logging.info('Done')
except Exception as ex:
	logging.error(ex.message)

