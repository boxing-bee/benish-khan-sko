# Sales Template

This repository contains a simple static HTML page that displays a "Hello World" message along with some placeholder text. 


## Usage

1. Use the deploy to Netlify button:

  [![Deploy to Netlify](https://www.netlify.com/img/deploy/button.svg)](https://app.netlify.com/start/deploy?repository=https://github.com/netlifyjoe/sales-template)


## Customization

Retrofit the public directory with your own HTML, CSS, and JS.  

## Clone LaunchDarkly SDKs + Relay Proxy

This repo includes a helper script that discovers and clones LaunchDarkly SDK repositories (and the Relay Proxy) using the GitHub CLI.

```bash
# list what would be cloned
scripts/clone-launchdarkly-sdks.sh --list

# shallow-clone (default depth=1) into ./launchdarkly-repos/
scripts/clone-launchdarkly-sdks.sh
```


