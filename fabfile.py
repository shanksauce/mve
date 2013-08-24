from __future__ import with_statement
import sys
import json
import config
import logging
import fabric.state
from fabric.colors import green, blue, red, yellow, cyan, magenta
from fabric.api import settings, hide, run, local, cd, lcd, get, env, execute
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
    logging.info(green('Cleaning up...'))
    with settings(hide('stderr'), warn_only=True):
        run('ls -la')

@hosts(config.X_HOSTS)
def make_env():
    logging.info('Setting up environment...')
    pass
