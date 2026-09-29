# Cloudflare Deployment Notes

배포가 요청된 경우에만 읽는다.

## Preferred Separation
- static dashboard: index.html / assets
- data: R2 object 또는 승인된 data endpoint
- access control: Cloudflare Access 등
- server-side logic: Workers

## Rules
- secret/API token을 HTML/JS에 넣지 않는다.
- 공개하면 안 되는 원본 Excel을 public bucket URL로 노출하지 않는다.
- CORS, content-type, cache 정책을 확인한다.
- 데이터 갱신 주기와 browser/edge cache 정책을 맞춘다.
- private dashboard는 인증/인가가 실제 데이터 경로까지 보호하는지 확인한다.

## R2 + Static Dashboard
동일 origin 상대경로면 `./data.xlsx` 같은 상대경로를 선호한다. 다른 origin이면 CORS와 Access 정책을 별도로 검토한다.

## Worker
역할을 인증된 요청 처리, R2 object fetch, response headers, 필요한 업로드 endpoint로 제한한다. 업로드를 만들면 인증, 파일 크기 제한, MIME validation, overwrite 정책을 둔다.
