# PICKLE proxy (Cloudflare Worker)

Holds the Anthropic key server-side. The app only knows `PICKLE_PROXY_URL`.

## Deploy

```bash
cd proxy
npx wrangler login                      # one-time, interactive
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler deploy                     # prints https://pickle-proxy.<account>.workers.dev
```

Then set `PICKLE_PROXY_URL` to the printed URL in `Config/Secrets.xcconfig`, clear
`ANTHROPIC_API_KEY` there, and rebuild. The app's `AIEstimation.make()` picks the
proxy automatically.

## Contract checks

```bash
BASE=https://pickle-proxy.<account>.workers.dev
curl -s $BASE/estimate -X POST -H 'content-type: application/json' \
  -d '{"text":"chipotle bowl with double chicken, brown rice, guac"}' | jq .
curl -s -o /dev/null -w '%{http_code}\n' $BASE/estimate -X POST -d 'not json'   # 400
curl -s -o /dev/null -w '%{http_code}\n' $BASE/estimate -X POST \
  -H 'content-type: application/json' -d '{}'                                   # 400
```

## Fast follows (tracked in TODOS.md)

- Abuse protection: rate limiting and/or App Attest before any public build.
- USDA FDC `/search` passthrough once the app grows a proxy search path.
