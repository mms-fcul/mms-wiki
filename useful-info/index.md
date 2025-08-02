---
title: Useful Information and Commands
layout: page
---

This section collects commonly used commands, configuration tips, and general reference information to help with daily work.

<ul>
  {% assign info_pages = site.pages | where_exp: "p", "p.path contains 'useful-info/'" %}
  {% assign sorted_pages = info_pages | sort: "title" %}
  {% for page in sorted_pages %}
    {% unless page.path == 'useful-info/index.md' %}
      <li><a href="{{ page.url | relative_url }}">{{ page.title }}</a></li>
    {% endunless %}
  {% endfor %}
</ul>
