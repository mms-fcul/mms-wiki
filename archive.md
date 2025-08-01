---
layout: page
title: Archive
permalink: /archive/
---

Welcome to the archive, where all pages come to die.
Here you'll find a list of all the pages, grouped by topic, in case you are looking for something specific.

<h2>Table of Contents</h2>

{%- assign content_folders = "new-to-mms,programs-and-tools,tutorials,useful-info" | split: "," -%}

{%- for folder in content_folders -%}
  {%- assign index_path = folder | append: "/index.md" -%}
  {%- assign folder_index = site.pages | where: "path", index_path | first -%}

  <h3>
    {%- if folder_index and folder_index.title -%}
      <a href="{{ folder_index.url | relative_url }}">
        {{ folder_index.title }}
      </a>
    {%- else -%}
      {{ folder | replace: "-", " " | capitalize }}
    {%- endif -%}
  </h3>

  <ul>
    {%- for page in site.pages -%}
      {%- if page.path contains folder and page.path != index_path and page.title -%}
        <li><a href="{{ page.url | relative_url }}">{{ page.title }}</a></li>
      {%- endif -%}
    {%- endfor -%}
  </ul>
{%- endfor -%}
