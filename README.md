# Sales Template

This repository contains a simple static HTML page that displays a "Hello World" message along with some placeholder text. 


## Usage

1. Use the deploy to Netlify button:

  [![Deploy to Netlify](https://www.netlify.com/img/deploy/button.svg)](https://app.netlify.com/start/deploy?repository=https://github.com/netlifyjoe/sales-template)


## Customization

Retrofit the public directory with your own HTML, CSS, and JS.  

## Cloning LaunchDarkly SDKs + Relay Proxy

This repo includes a helper script that clones **all LaunchDarkly GitHub org repos whose names match `sdk`** (plus the Relay Proxy repos, e.g. `ld-relay`) into a local folder that is **git-ignored**.

```bash
chmod +x scripts/clone_launchdarkly_sdks_and_relay.sh

# fast (shallow) clone into ./launchdarkly-repos (default)
scripts/clone_launchdarkly_sdks_and_relay.sh

# full clone history (slower, larger)
scripts/clone_launchdarkly_sdks_and_relay.sh --depth 0
```

