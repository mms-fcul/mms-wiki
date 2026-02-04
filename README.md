# MMS Wiki - Contributor Guide

Welcome! This document helps you set up and contribute to the [MMS Wiki website](https://mms-fcul.github.io/mms-wiki/).

---
# Pre-requisites

To be able to host the local version of the website (very useful for editing because you can preview your changes instantly) you are required to have the following installed:
- **Ruby**  
- **Bundler** gem  
- **Jekyll** gem  

First, let's make sure we have all the necessary system dependencies with:
```
sudo apt update
sudo apt install -y build-essential libssl-dev libreadline-dev zlib1g-dev libsqlite3-dev libyaml-dev libgmp-dev libncurses5-dev libffi-dev libdb-dev libgdbm-dev libgdbm-compat-dev libx11-dev libxcb1-dev libx11-xcb-dev libxrender-dev libxtst-dev libxi-dev autoconf bison libxml2-dev libxslt1-dev libcurl4-openssl-dev libtool unixodbc-dev pkg-config ruby ruby-dev
rbenv install 3.3.1
rbenv global 3.3.1
ruby -v
```

You can install Bundler and Jekyll by running:
```
gem install bundler jekyll
```

Lastly,  we need to install the bundler dependencies. For that run Bundler to install all required gems:

```
sudo bundle install
```
You will get a warning saying that running this as sudo is not recomended but if you don't do this you won't have permissions to write to /usr/lib/ruby. This is due to the setup of our cluster. If you are doing this in a home machine you shouldn't need to use sudo.

---

<br>
<br>
<br>

# How to contribute
As this is a colaborative wiki, we ask that you make sure to always push your code after you have made a change, to avoid creating forks and losing changes.
## 1. Pull the code
### Clone the Repository
If you haven’t already, clone the repository:

```
git clone https://github.com/mms-fcul/mms-wiki.git
cd mms-wiki
```
This creates a local version of the git repository, with a copy of all the files that you can edit as local files.

<br>

### Getting the updated code
If you already have a local clone of the repository, you can update it by running:

```
git pull origin main
```

**You should do this everytime you are making local changes.**

Now you are updated and ready to make changes!

<br>
<br>

## 2. Editing files
There are multiple files within the repository, a lot of them have to do with the configuration of the website. We ask that unless you know what you're doing to not mess around with them.

The content of the wiki itself is stored inside the `/new-to-mms/`, `/programs-and-tool/`, `/tutorials/` and `/useful-info/`.
If you want to edit or expand on the pages that already exist, simply edit them with a normal text editor.

If you want to create a new page, create a newpage.md file within the adequate folder ( `/new-to-mms/`, `/programs-and-tool/`, `/tutorials/` or `/useful-info/`), and use the template header:

```
---
layout: page
title: Example title
pinned: false
---

Example text
```
It is important to name your files .md. This is short for markdown, the language used. If you don't add this extension the file will not be interpreted as content by Jekyll and will not show up in the website.

The header is also very important, as it changes how the file will be formatted in the website. This is mainly defined by the layout tag. The pinned tag is used to pin posts or pages to the Notice Board and Pinned Pages sections respectively.
- In order to show up in the Notice Board it should be tagged as
```
  layout: post
  pinned: true
```
- In order to show up in the Pinned Pages it should be tagged as
```
  layout: page
  pinned: true
```

<br>

### Running Locally
To test your changes locally, run the Jekyll server:

```
bundle exec jekyll serve
```

Once running, open this URL in your browser: [http://localhost:4000/mms-wiki/](http://localhost:4000/mms-wiki/)

This is a local version of the website being hosted in your machine. Any changes you make will instantly be applied once you save any modified files, but nobody else will be able to see them because they only exist within the local files in your computer. In order to make them permanent/public you need to upload the files into the git repository. This is the oposite of what you did when you pulled the code, instead of copying (or updating your local files with) the git files you are updating the git files with your changes. 

<br>
<br>

## 3. Pushing your changes
### Important Notes Before Pushing
- Remove any temporary or backup files (such as files ending with ~) before committing and pushing to the repository.
- Review your changes carefully.

<br>

### Committing and Pushing Changes
```
git add .
git commit -m "Describe your changes here"
git push origin main
```

The last command will prompt you to insert credentials, you must insert your personal username and password or token.

You can generate a personal token by going to Settings > Developer settings > Personal access tokens → Tokens (classic) > Generate new token → Generate new token (classic).

### Verify Changes Online
After pushing, visit the live site at: [https://mms-fcul.github.io/mms-wiki/](https://mms-fcul.github.io/mms-wiki/)
to verify your updates are correctly deployed (it may takes a few minutes for the changes to become live).

---

<br>
<br>
<br>

# If you are curious how things work behind the curtain, have a peek:
Git-based websites are hosted by github itself, but there is some magic that happens to turn a normal repository into a website. The  ingredients for this magic spell are Ruby, Bundler and Jekyll

## What is Ruby?
Ruby is a dynamic, open-source programming language focused on simplicity and productivity. It’s widely used for web development, scripting, and building software tools. Many popular tools and frameworks, including Jekyll, are written in Ruby.

## What is Bundler?
Bundler is a Ruby gem (package) that manages an application's dependencies. It ensures that the correct versions of gems (libraries) are installed and loaded, so your Ruby projects run consistently across different environments. Bundler simplifies installing, updating, and managing gems.

## What is Jekyll?
Jekyll is a static site generator built with Ruby. It takes your content written in Markdown or HTML, applies templates, and generates a complete static website — no database or server-side processing needed. Jekyll is commonly used to build blogs, project pages, and documentation sites, especially on GitHub Pages.

## How They Work Together (aka how to cast the magic spell)
- Ruby provides the runtime environment and language.
- Bundler manages Ruby gem dependencies, making sure you have the right versions of Jekyll and its plugins.
- Jekyll uses Ruby to process your site content and build the final static website files.

## In practice
The line `baseurl: "/mms-wiki" ` in the _config.yml is what's binding the git repository with the deployed website, in turn generating the url.

## If you are interested in the layout of the pages
These are defined by the index.md file. The contents of the pages for the various categories  ( `/new-to-mms/`, `/programs-and-tool/`, `/tutorials/` or `/useful-info/`) are encoded into the index.md in their respective folders. 

The home page is a special page. It's layout is encoded in the _layouts/home.html file. As the extension implies is written in html, not in markdown (like the index.md), but don't let that scare you off, html isn't that complicated and it's very powerful for more complex functions like filtering and ordering content pages.

```
<div style="margin-top: 12em; display: flex; gap: 2em; flex-wrap: wrap;">
  <div style="flex: 1; min-width: 250px;">
    <h2>ᕕ( ﾟヮﾟ)ᕗ Notice Board</h2>
    <ul>
      {% assign pinned_posts = site.posts | where: "pinned", true | where: "category", "post" %}
{% for post in pinned_posts %}
      <div style="margin-bottom: 2em;">
	<h3><a href="{{ post.url | relative_url }}">{{ post.title }}</a></h3>
	<div>{{ post.content | markdownify }}</div>
      </div>
      {% endfor %}
    </ul>
  </div>
  <div style="flex: 1; min-width: 250px;">
    <h2>Pinned Pages 👇( ｡ ‿ ｡ ) </h2>
    <ul>
      {% assign pinned_pages = site.pages | where: "pinned", true | where: "category", "page" %}
      {% for page in pinned_pages %}
        <li><a href="{{ page.url | relative_url }}">{{ page.title }}</a></li>
      {% endfor %}
    </ul>
  </div>
</div>

```
With this we are able to separate files that have the `pinned: true` tag into posts and pages, to be storted for the Notice Board and Pinned Pages respectivelly. This avoids the creation of specific categories, and allows us to pin any file from anywhere in the website just by modifying the `pinned` tag .


If you dig around you will find that this distiction between .md and .html isn't that set in stone. Let's take the archive.md file for example. There is some markdown content, but in order to implement the alphabetical ordering per catergory html was required. Jekyll is very flexible in this regard and you can play around with these languages almost interchangably and it will still work.

---
# If you have any questions, feel free to reach out!
