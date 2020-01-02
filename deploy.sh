#!/usr/bin/env bash

hexo clean
hexo g

cp -r ./baidu_verify_vMTOPbD1V1.html public/



hexo d

git add .
git commit -m "update" .
git push origin gh-pages