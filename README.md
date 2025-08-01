# MMS Wiki - Contributor Guide

Welcome! This document helps you set up and contribute to the MMS Wiki website.

---

## Prerequisites

Make sure you have the following installed:
- **Ruby** (version 2.7 or higher recommended)  
- **Bundler** gem  
- **Jekyll** gem  

You can install Bundler and Jekyll by running:
`gem install bundler jekyll`

## Clone the Repository
If you haven’t already, clone the repository:
`git clone https://github.com/mms-fcul/mms-wiki.git`
`cd mms-wiki`

### Install Dependencies
Run Bundler to install all required gems:
`bundle install`

### Running Locally
To test your changes locally, run the Jekyll server:
`bundle exec jekyll serve`
Once running, open this URL in your browser:
`http://localhost:4000/mms-wiki/`

### Important Notes Before Pushing
- Remove any temporary or backup files (such as files ending with ~) before committing and pushing to the repository.
- Review your changes carefully.

### Committing and Pushing Changes
`git add .`
`git commit -m "Describe your changes here"`
`git push origin main`
The last command will prompt you to insert credentials, you must insert your personal username and password or token (you can generate a personal toke by going to Settings > Developer settings > Personal access tokens → Tokens (classic) > Generate new token → Generate new token (classic))

### Verify Changes Online
After pushing, visit the live site at:
`https://mms-fcul.github.io/mms-wiki/`
to verify your updates are correctly deployed.

If you have any questions, feel free to reach out!
