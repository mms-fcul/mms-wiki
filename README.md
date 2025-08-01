# MMS Wiki - Contributor Guide

Welcome! This document helps you set up and contribute to the MMS Wiki website.

---

# Prerequisites

Make sure you have the following installed:
- **Ruby** (version 2.7 or higher recommended)  
- **Bundler** gem  
- **Jekyll** gem  

You can install Bundler and Jekyll by running:
```
gem install bundler jekyll
```

# How to contribute
As this is a colaborative wiki, we ask that you make sure to always push your code after you have made a change, to avoid creating forks and losing changes.
## 1. Pull the code
### Clone the Repository
If you haven’t already, clone the repository:

```
git clone https://github.com/mms-fcul/mms-wiki.git
cd mms-wiki
```

### Install Dependencies
Run Bundler to install all required gems:

```
bundle install
```

### Getting the updated code
If you already have a local clone of the repository, you can update it by running:

```
git pull origin main
```


Now you are updated and ready to make changes!

## 2. Editing files
There are multiple files within the repository, most of them have to do with the configuration of the website. We ask that unless you know what you're doing to not mess around with them.

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


### Running Locally
To test your changes locally, run the Jekyll server:

```
bundle exec jekyll serve
```

Once running, open this URL in your browser: [http://localhost:4000/mms-wiki/](http://localhost:4000/mms-wiki/)

## 3. Pushing your changes
### Important Notes Before Pushing
- Remove any temporary or backup files (such as files ending with ~) before committing and pushing to the repository.
- Review your changes carefully.

### Committing and Pushing Changes

```
git add .
git commit -m "Describe your changes here"
git push origin main
```

The last command will prompt you to insert credentials, you must insert your personal username and password or token (you can generate a personal toke by going to Settings > Developer settings > Personal access tokens → Tokens (classic) > Generate new token → Generate new token (classic))

### Verify Changes Online
After pushing, visit the live site at: [https://mms-fcul.github.io/mms-wiki/](https://mms-fcul.github.io/mms-wiki/)
to verify your updates are correctly deployed.

If you have any questions, feel free to reach out!
