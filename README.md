# adms (aasaam distributed media server)

## Why

Scaling and maintain file storage is one the most use case. Using AWS/GCS and etc not accessible by all users and some post process of files like converting will be difficult.

### Key features

* Convert Video/Audio to standard HLS.
* tusd Upload support.
* Multi domains/buckets.
* CDN/Secure/Performance in mind design.
* POSIX Design. For independent any solution
* Shardable/Distributed Design.
* Thumbnail generation.

## Configurations

All environment variable must has prefix `ASM_`.

* Start with `ASM_PUBLIC` will expose as public configuration, otherwise consideration as secure/private variable.

| Public Environment Variable           | Default             | Change? | Description                                                                          |
| ------------------------------------- | ------------------- | ------- | ------------------------------------------------------------------------------------ |
| `ASM_PUBLIC_SERVER_ID`                | `0`                 | 🚀       | **IMPORTANT** Server identifier for each deployment, Must be base36 `[a-z0-9]{1,32}` |
| `ASM_PUBLIC_APP_INSTANCE`             | `2`                 | 🔧       | Number of HTTP application instance using PM2                                        |
| `ASM_PUBLIC_SERVER_MAINTAIN`          | `false`             | 🚫       | Is server on maintain mode for just serve no new upload accepted                     |
| `ASM_PUBLIC_POST_UPLOADED_SIZE_BYTES` | `4194304` (4MB)     | 🔧       | Max POST body size for accept upload in Mega Bytes, both tus client and HTTP POST    |
| `ASM_PUBLIC_TUSD_PATH`                | `/resumable-upload` | 🔴       | Path of tusd server for accept tus client requests.                                  |

| Secure/Private Environment Variable | Default                   | Change? | Description                                            |
| ----------------------------------- | ------------------------- | ------- | ------------------------------------------------------ |
| `ASM_DOWNLOADER_DNS_SERVERS`        | `4.2.2.4,8.8.8.8,1.1.1.1` | 🔧       | List of dns server that `curl` will try to resolve     |
| `ASM_DOWNLOADER_LIMIT_RATE_KB`      | `256`                     | 🔧       | Limit the download speed that `curl` used in KiloBytes |
| `ASM_TUSD_PORT`                     | `1080`                    | 🔴       | Port of tusd container to listen behind nginx          |
| `ASM_UPLOAD_PORT`                   | `8080`                    | 🔧       | Nginx port for upload host                             |
| `ASM_SERVE_PORT`                    | `8880`                    | 🔧       | Nginx port for upload host                             |
| `ASM_MAIN_APP_PORT`                 | `3000`                    | 🔴       | Node.JS main application HTTP port                     |
| `ASM_AUTH_APP_PORT`                 | `3001`                    | 🔴       | Node.JS auth application HTTP port                     |
| `ASM_REDIS_URI`                     | `redis://adms-redis`      | 🔴       | Redis container host                                   |
| `ASM_NGINX_WORKER_PROCESSES`        | `2`                       | 🔧       | Nginx `worker_processes`                               |
| `ASM_NGINX_WORKER_RLIMIT_NOFILE`    | `2048`                    | 🔧       | Nginx `worker_rlimit_nofile`                           |
| `ASM_NGINX_WORKER_CONNECTIONS`      | `1024`                    | 🔧       | Nginx `worker_connections`                             |

### Change references

This simple emoji show when to change the variables of adms;

* 🚀: Config this variable during launch time and **NEVER** change it.
* 🔧: Config of this could be change any time for changing application workload/behavior.
* 🚫: Config of this variable may cause service different behavior.
* 🔴: Config of this variable is for special use cases or testing, do not touch it if you're not knowing how that works.

## Storage

| Path             | Partition # | Type      | Description                                        |
| ---------------- | ----------- | --------- | -------------------------------------------------- |
| `/storage/files` | A           | Persist   | **IMPORTANT** Files store on this path             |
| `/storage/tusd`  | A           | Temporary | tusd use for uploaded chunks                       |
| `/storage/cache` | X           | Temporary | application use for generate thumbnails and etc... |

### Storage path

We have server id `0`, bucket `localhost` with file hash `2x7pLVtJRWkwaq` that contain simple `jpeg` file;

| Which             | Path                                        | Description                    |
| ----------------- | ------------------------------------------- | ------------------------------ |
| `[BUCKET_PATH]`   | `/storage/files/0/localhost`                | Path of each bucket            |
| `[FILE_DIR]`      | `[BUCKET_PATH]/q/kw/2x7pLVtJRWkwaq`         | Path of file directory         |
| `[FILE_ORIGINAL]` | `[FILE_DIR]/o.jpg`                          | Path of original uploaded file |
| `[FILE_META]`     | `[BUCKET_PATH]/q/kw/2x7pLVtJRWkwaq/.m.json` | Path of file meta data json    |

#### Storage notes

* For best practices is good to use base62 of using mongodb ObjectID for easy integration. (eg `507f1f77bcf86cd799439011` is `2x7pLVtJRWkwaq`)
* `[FILE_DIR]` use `levels=1:2` hash of file like [nginx proxy_cache_path level](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_path) for gain more performance and backup in mind solutions for `rsync`.

## Buckets

Each deployment need bucket files that standard json file

```jsonc
[
  {
    // identifier of buckets
    "id": "localhost",
    // if active and new upload will be proceed otherwise just serve will work
    "active": true,
    // is private that each serve request need JWT token for access data, otherwise all files is public resource.
    "private": false,
    // list of domains that accepted by this bucket
    "domains": [
      "localhost",
      "127.0.0.1"
    ],
    // list of vod qualities that convert to HLS
    "vod": [
      "360p",
      "720p"
    ],
    // list of aod qualities that convert to HLS
    "aod": [
      "128k"
    ],
    // JWT HS256 secret for sign/verify upload token
    "upload_secret": "upload_secret",
    // JWT HS256 secret for delete or get info of server
    "management_secret": "management_secret",
    // JWT HS256 secret for sign/verify serve token
    "serve_secret": "serve_secret"
  }
]
```

### Bucket notes

* For thumbnail generation JWT token require for prevent DoS/DDoS of cpu usage, even server is public `"private": false`.
* Domains must unique across all buckets.

## Deployment example

Consider you have sample `example.com` and you need store media files.
We need scale media server to two servers.

### Design approach

Scaling and distribute requirement to calculate many parameters.

* How much you will need for post processors.
* How much need space for your media.

### Private or protected servers

These server could be private or protected via any mechanism like vpn, wireguard, [upstream secure](https://docs.nginx.com/nginx/admin-guide/security-controls/securing-http-traffic-upstream/) or etc.

| Host    | IP         | Description   |
| ------- | ---------- | ------------- |
| `adms0` | `10.0.1.0` | adms node `0` |
| `adms1` | `10.0.1.1` | adms node `1` |

### Public servers

Consider we have public ip like `5.x.x.x`.

`up[N].example.com` will accept the upload request and process the media and files.
`s[N].example.com` will serve the content via cache in CDN/Reverse Proxy layer for increase your throughput.

| Host              | IP        | Upstream                | Description                                      |
| ----------------- | --------- | ----------------------- | ------------------------------------------------ |
| `up0.example.com` | `5.5.1.0` | `adms0:ASM_UPLOAD_PORT` | adms node `0` for accept uploads                 |
| `up1.example.com` | `5.5.1.1` | `adms1:ASM_UPLOAD_PORT` | adms node `1` for accept uploads                 |
| `s0.example.com`  | `5.5.2.0` | `adms0:ASM_SERVE_PORT`  | adms node `0` for serve media (Scale serving 1x) |
| `s0.example.com`  | `5.5.2.1` | `adms0:ASM_SERVE_PORT`  | adms node `0` for serve media (Scale serving 2x) |
| `s0.example.com`  | `5.5.2.2` | `adms0:ASM_SERVE_PORT`  | adms node `0` for serve media (Scale serving 3x) |
| `s1.example.com`  | `5.5.2.0` | `adms1:ASM_SERVE_PORT`  | adms node `1` for serve media (Scale serving 1x) |
| `s1.example.com`  | `5.5.2.1` | `adms1:ASM_SERVE_PORT`  | adms node `1` for serve media (Scale serving 2x) |
| `s1.example.com`  | `5.5.2.2` | `adms1:ASM_SERVE_PORT`  | adms node `1` for serve media (Scale serving 3x) |

Now you can upload and process in two separate nodes.

For increase high serving content you can add more `s[N].example.com` node and cache serving content.
