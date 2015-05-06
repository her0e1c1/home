### Python Code

PYALIAS_PYTHON='python3 -c'
PYALIAS_IMPORT='
from os.path import isdir, exists, join, basename
from os import environ
from sys import exit
from shutil import copy, rmtree, move
from argparse import ArgumentParser
'

alias rm="python -c \"
$PYALIAS_IMPORT
p = ArgumentParser()
p.add_argument('-v', dest='verbose', action='store_true')
p.add_argument('paths', nargs='+')
args = p.parse_args()
trash = join(environ['HOME'], '.trash')
for p in args.paths:
    counter = 0
    while True:
        if not exists(p):
            print('Not exists: {}'.format(p))
            break
        b = basename(p)
        if counter > 0:
            b += '_{}'.format(counter)
        dst = join(trash, b)
        if not exists(dst):
            if args.verbose:
                print('move {p} {dst}'.format(**locals()))
            move(p, dst)
            break
        counter += 1
\""

alias pytrash='python3 -c ''
from os.path import *
from shutil import *
import os
import argparse
p = argparse.ArgumentParser()
p.add_argument("-r", action="store_true")
args = p.parse_args()
trash = join(os.environ["HOME"], ".trash")
if not isdir(trash):
    os.makedirs(trash)
if args.r:
    rmtree(trash)
else:
    for t in os.listdir(trash):
        print(t)
'''

alias pyswap="$PYALIAS_PYTHON \"
$PYALIAS_IMPORT
p = ArgumentParser()
p.add_argument('paths', nargs=2)
args = p.parse_args()
for p in args.paths:
    if not exists(p):
        print('No {} exists'.format(p))
        exit()
\""

alias urlencode='python -c "import sys, urllib as ul; print(ul.quote_plus(sys.argv[1]))"'
alias urldecode='python -c "import sys, urllib as ul; print(ul.unquote_plus(sys.argv[1]))"'
