from __future__ import with_statement
import sys
import json
import time
import config
import logging
import fabric.state
from fabric.colors import green, blue, red, yellow, cyan, magenta
from fabric.api import settings, hide, run, local, cd, lcd, get, env, execute, task
from fabric.decorators import hosts

config.configure_logging()

env.user = 'root'
fabric.state.output['running'] = False

def help(method=None):
    '''
    Usage: fab help:[command]
    Available values for command are: 'deploy', 'package'. The default is to display this message.
    Example usage:
        fab help:deploy
    '''
    m = help
    if method == 'deploy':
        m = deploy
    elif method == 'package':
        m = package
    print blue(m.__doc__, True)
    sys.exit(0)


@hosts(config.X_HOSTS)
def ls():
    with settings(hide('stderr'), warn_only=True):
        with cd('~/mve'):
            run('ls -la *.p')

@hosts(config.X_HOSTS)
def install_libevent():
    with settings(warn_only=True):
        with cd('/usr/src'):
            run('rm -rf libevent*')
            run('wget https://github.com/downloads/libevent/libevent/libevent-2.0.21-stable.tar.gz')
            run('tar xzf libevent-2.0.21-stable.tar.gz')
        with cd('/usr/src/libevent-2.0.21-stable'):
            run('./configure --prefix=/usr')
            run('make')
            run('make install')

@hosts(config.X_HOSTS)
def setup_env():
    with settings(warn_only=True):
        run('wget https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py -O - | python')
        run('wget https://raw.github.com/pypa/pip/master/contrib/get-pip.py -O - | python')
        run('pip install virtualenv')
        with cd('~/mve'):
            run('virtualenv venv; source venv/bin/activate; pip install -r etc/pip.requirements')

@hosts(config.X_HOSTS)
def update_system():
    with settings(warn_only=True):
        run('slackpkg update')

@hosts(config.X_HOSTS)
def check_cluster():
    run('ps aux | grep mongo')

@hosts(config.X_HOSTS)
def check_celery():
    run('ps aux | grep celery')

@hosts(config.MONGOS_HOSTS)
def restart_mongos():
    with settings(hide('stdout', 'stderr', 'warnings'), warn_only=True):
        PIDFILE = '/var/run/mongos.pid'
        LOGPATH = '/var/log/mongos'
        CONFIG_DBS = ','.join(config.MONGOD_CONFIG_HOSTS)
        def stop():
            logging.info(green('Stopping mongos...'))
            run('truncate -s 0 {0}'.format(LOGPATH))
            if fabric.contrib.files.exists(PIDFILE):
                run('kill -s 2 $(cat {0}) && rm {0}'.format(PIDFILE))
        def start():
            logging.info(green('Starting mongos...'))
            cmd = '/usr/bin/mongos --pidfilepath {0} --logpath {1} --configdb {2} --logappend --fork'.format(PIDFILE, LOGPATH, CONFIG_DBS)
            logging.info(yellow('Running' + cmd))
            run(cmd)
            logging.info(green('PID is ' + run('cat {0}'.format(PIDFILE))))
            logging.info('')
        stop()
        start()

@hosts(config.MONGOD_CONFIG_HOSTS)
def restart_mongod_config():
    with settings(hide('stdout', 'stderr', 'warnings'), warn_only=True):
        PIDFILE = '/var/run/mongod.config.pid'
        DBPATH = '/var/data/configdb'
        LOGPATH = '/var/log/mongod.config'
        def stop():
            logging.info(green('Stopping mongod...'))
            run('truncate -s 0 {0}'.format(LOGPATH))
            if fabric.contrib.files.exists(PIDFILE):
                run('kill -s 2 $(cat {0}) && rm {0}'.format(PIDFILE))
        def start():
            logging.info(green('Starting mongod...'))
            cmd = '/usr/bin/mongod --configsvr --pidfilepath {0} --logpath {1} --dbpath {2} --logappend --fork'.format(PIDFILE, LOGPATH, DBPATH)
            logging.info(yellow('Running' + cmd))
            run(cmd)
            logging.info(green('PID is ' + run('cat {0}'.format(PIDFILE))))
            logging.info('')
        stop()
        start()

@hosts(config.X_HOSTS)
def restart_mongod():
    with settings(hide('stdout', 'stderr', 'warnings'), warn_only=True):
        PIDFILE = '/var/run/mongod.pid'
        DBPATH = '/var/data/db'
        LOGPATH = '/var/log/mongod'
        PORT = '27070'
        def stop():
            logging.info(green('Stopping mongod...'))
            run('truncate -s 0 {0}'.format(LOGPATH))
            if fabric.contrib.files.exists(PIDFILE):
                run('kill -s 2 $(cat {0}) && rm {0}'.format(PIDFILE))
        def start():
            logging.info(green('Starting mongod...'))
            cmd = '/usr/bin/mongod --port {0} --pidfilepath {1} --logpath {2} --dbpath {3} --logappend --fork'.format(PORT, PIDFILE, LOGPATH, DBPATH)
            logging.info(yellow('Running' + cmd))
            run(cmd)
            logging.info(green('PID is ' + run('cat {0}'.format(PIDFILE))))
            logging.info('')
        stop()
        start()

@hosts(config.X_HOSTS)
def rm_scrape_urls():
    with cd('~/mve'):
        run('rm -f scrape_urls.')

@hosts(config.X_HOSTS)
def kill_celery():
    PIDFILE = '/var/run/celery.pid'
    LOGFILE = '/var/log/celery'
    with settings(warn_only=True):
        if fabric.contrib.files.exists(PIDFILE):
            run('kill -s 2 $(cat {0}) && rm {0}'.format(PIDFILE), pty=False)
            run('killall celery', pty=False)
            run('truncate -s 0 {0}'.format(LOGFILE))

def restart_celery():
    with settings(warn_only=True):
        @hosts(config.WORKER_HOSTS)
        def restart_celery_workers():
            PIDFILE = '/var/run/celery.pid'
            LOGFILE = '/var/log/celery'
            if fabric.contrib.files.exists(PIDFILE):
                run('kill -s 2 $(cat {0}) && rm {0}'.format(PIDFILE), pty=False)
                run('killall celery', pty=False)
                run('truncate -s 0 {0}'.format(LOGFILE))
            time.sleep(10)
            with cd('~/mve'):
                run('source venv/bin/activate; nohup celery worker --pidfile={0} --logfile={1} -l INFO -E -A celerytasks >& /dev/null < /dev/null &'.format(PIDFILE, LOGFILE), pty=False)

        @hosts(config.BEAT_HOST)
        def restart_celery_beat():
            PIDFILE = '/var/run/celery.pid'
            LOGFILE = '/var/log/celery'
            if fabric.contrib.files.exists(PIDFILE):
                run('kill -s 2 $(cat {0}) && rm {0}'.format(PIDFILE))
                run('killall celery', pty=False)                
                run('truncate -s 0 {0}'.format(LOGFILE))
            time.sleep(10)
            with cd('~/mve'):
                run('source venv/bin/activate; nohup celery worker --pidfile={0} --logfile={1} -l INFO -E -B -A celerytasks >& /dev/null < /dev/null &'.format(PIDFILE, LOGFILE), pty=False)

        @hosts(config.FLOWER_HOST)
        def restart_celery_flower():
            PIDFILE = '/var/run/celery-flower.pid'
            LOGFILE = '/var/log/celery-flower'
            if fabric.contrib.files.exists(PIDFILE):
                run('kill -s 2 $(cat {0}) && rm {0}'.format(PIDFILE), pty=False)
                run('killall celery', pty=False)                
                run('truncate -s 0 {0}'.format(LOGFILE))
            time.sleep(10)
            with cd('~/mve'):
                run('source venv/bin/activate; nohup celery flower --pidfile={0} --logfile={1} >& /dev/null < /dev/null &'.format(PIDFILE, LOGFILE), pty=False)

        logging.info(yellow('Restarting celery flower...'))
        execute(restart_celery_flower)

        logging.info(yellow('Restarting celery beat...'))
        execute(restart_celery_beat)

        logging.info(yellow('Restarting celery workers...'))
        execute(restart_celery_workers)

@hosts(config.X_HOSTS)
def update_env():
    logging.info(yellow('Updating environment...'))
    with settings(warn_only=True):
        with cd('~/mve'):
            run('git pull origin master; source venv/bin/activate; pip install -q -r etc/pip.requirements', pty=False)



