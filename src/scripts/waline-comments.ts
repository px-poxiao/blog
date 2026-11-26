import type { WalineInstance } from "@waline/client";

class BlogComments extends HTMLElement {
	private instance?: WalineInstance | null;
	private generation = 0;

	connectedCallback() {
		const allowed = this.dataset.allowedOrigin;
		const local = ["localhost", "127.0.0.1", "[::1]"].includes(
			location.hostname,
		);
		if (allowed !== location.origin && !(allowed === "local" && local)) return;

		this.hidden = false;
		const retry = this.querySelector<HTMLButtonElement>(
			"[data-comments-retry]",
		);
		if (retry) retry.onclick = () => void this.mount();
		void this.mount();
	}

	disconnectedCallback() {
		// Swup replaces the article. Ignore any import still in progress for the old page.
		this.generation++;
		this.instance?.destroy();
		this.instance = undefined;
	}

	private async mount() {
		const mount = this.querySelector<HTMLElement>("[data-comments-mount]");
		const status = this.querySelector<HTMLElement>("[data-comments-status]");
		const retry = this.querySelector<HTMLButtonElement>(
			"[data-comments-retry]",
		);
		const path = this.dataset.commentPath;
		if (!mount || !status || !retry || !path || this.instance) return;

		const generation = ++this.generation;
		status.hidden = false;
		status.textContent = "正在加载留言区…";
		retry.classList.add("hidden");

		try {
			const [{ init }] = await Promise.all([
				import("@waline/client"),
				import("@waline/client/waline.css"),
			]);
			if (!this.isConnected || generation !== this.generation) return;
			this.instance = init({
				el: mount,
				serverURL: new URL("/waline", location.origin).href,
				path,
				lang: "zh",
				dark: "html.dark",
				login: "disable",
				meta: ["nick"],
				requiredMeta: [],
				reaction: false,
				emoji: false,
				imageUploader: false,
				search: false,
				texRenderer: false,
				noRss: true,
				wordLimit: [1, 1500],
				locale: { nick: "昵称（选填）", placeholder: "说点什么吧…" },
			});
			status.hidden = true;
		} catch {
			if (!this.isConnected || generation !== this.generation) return;
			status.textContent = "留言区暂时加载不了。";
			retry.classList.remove("hidden");
		}
	}
}

if (!customElements.get("blog-comments")) {
	customElements.define("blog-comments", BlogComments);
}
