# 给博客接入 Waline

博客仍是静态站。生产文章页从同域名的 `/waline/api/comment` 读取和提交评论。GitHub Pages 预览没有评论卡片，不会访问生产库。后端在同一服务器上独立运行，不改现有博客部署脚本，不需要另一个域名或证书。

## 服务器首次部署

以下命令在有 Docker Compose、curl 和 openssl 的服务器上执行。把本目录的文件完整复制到一个独立位置（如 `/opt/blog-waline`），不要放进博客的 Web 根目录、发布目录或 Git 仓库的已跟踪文件里。Compose 支持 amd64 和 arm64。

```sh
cd /opt/blog-waline
sh ./init.sh
docker compose config --quiet
docker compose up -d
docker compose ps
curl -fsS -e http://127.0.0.1:8360/ \
  'http://127.0.0.1:8360/api/comment?path=%2Fposts%2Fhealth-check&page=1&pageSize=5&lang=zh'
```

初始化脚本不会覆盖已有数据库或密钥。保留 `.env`，它含有会话签名密钥，勿上传或粘贴到聊天中。

### 创建管理员（仅 SSH 隧道）

容器端口只绑定在服务器回环地址上。**第一个注册账号会成为管理员**，不要把注册页面暴露到公网。在自己的电脑上保持此命令运行，SSH 密码只在 SSH 提示符输入：

```sh
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:18360:127.0.0.1:8360 用户名@服务器地址
```

在自己电脑的浏览器打开 `http://127.0.0.1:18360/ui/`，注册并登录，确认能看到评论管理。管理员邮箱和密码与 SSH 无关。日后管理评论也通过同样的隧道进入。

### 接入生产 Nginx

1. 先备份实际处理 `https://blog.px-poxiao.cn` 公网请求的 HTTPS 配置。仓库的 `deploy/blog.nginx.conf` 是监听 `127.0.0.1:3500` 的静态站配置，不一定是公网入口。
2. 将 `nginx-location.conf` 的两个 `location` 放在公网 HTTPS `server` 块里，保留现有博客路由。需要在能看到真实访客 IP 的入口转发，别用客户端自报的转发头。如果前面有可信 CDN 或反代，先确认对应的 Nginx Real IP 配置，避免所有访客共用一个限速桶。
3. `sudo nginx -t` 通过后再 `sudo systemctl reload nginx`（面板管理的 Nginx 用面板对应的重载方式）。在合并前检查：
   ```sh
   curl -fsS -e https://blog.px-poxiao.cn/ \
     'https://blog.px-poxiao.cn/waline/api/comment?path=%2Fposts%2Fhealth-check&page=1&pageSize=5&lang=zh'
   curl -sS -o /dev/null -w '%{http_code}\n' https://blog.px-poxiao.cn/waline/ui/
   curl -sS -o /dev/null -w '%{http_code}\n' https://blog.px-poxiao.cn/waline/api/user
   ```
   第一条应返回 `errno: 0` 和空列表，后两条应为 404。
4. 后端就绪后再合并分支。现有 GitHub Actions 会把 Astro 静态文件部署到服务器。用匿名窗口验证发帖、回复、两篇文章不串评论，再在管理后台删除测试留言。默认同一 IP 发帖间隔 20 秒，测试回复时记得等一下。

## 日常维护

- 每篇文章设一个唯一的 `commentId`，改文件名或页面地址时不改它。缺省用文章 slug；如果以后可能改 slug，请在首次开放评论前设置固定 ID。
- 评论无需登录、邮箱或验证码；提交直接显示。开启基础 IP 限速，未接 Akismet 或其他外部审核。首版关闭图片上传和点赞。
- 不公开地理位置和浏览器信息；Waline 仍会为限速记录 IP。仅管理员本人可访问后台和数据库，妥善保管备份。
- 备份时暂停容器再复制 `data/` 和 `.env` 到仅自己能访问的位置，或用 SQLite 的在线备份命令。避免发布数据库及其日志文件。
- 回滚可先回退前端提交或取消 Nginx 转发，数据库不用删除；停止服务用 `docker compose stop`。

参考：[Waline 自托管](https://waline.js.org/guide/deploy/vps.html) · [环境变量](https://waline.js.org/reference/server/env.html)
