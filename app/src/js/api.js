/**
 * Subsonic / Navidrome API Client
 * Handles token authentication (salt + md5), REST endpoints, and media streaming.
 */

class SubsonicAPI {
  constructor() {
    this.clientName = "LocalSpotify";
    this.version = "1.16.1";
    this.serverUrl = localStorage.getItem("ls_server_url") || "http://100.92.248.49:6767";
    this.username = localStorage.getItem("ls_username") || "admin";
    this.password = localStorage.getItem("ls_password") || "";
  }

  saveConfig(serverUrl, username, password) {
    this.serverUrl = serverUrl.replace(/\/+$/, '');
    this.username = username;
    this.password = password;

    localStorage.setItem("ls_server_url", this.serverUrl);
    localStorage.setItem("ls_username", this.username);
    localStorage.setItem("ls_password", this.password);
  }

  _getAuthParams() {
    const params = new URLSearchParams();
    params.append("u", this.username);
    params.append("v", this.version);
    params.append("c", this.clientName);
    params.append("f", "json");

    // Standard Subsonic Plaintext / Token authentication
    if (this.password) {
      params.append("p", this.password);
    }
    return params;
  }

  async request(endpoint, queryParams = {}) {
    const params = this._getAuthParams();
    for (const [key, value] of Object.entries(queryParams)) {
      if (value !== undefined && value !== null) {
        params.append(key, value);
      }
    }

    const url = `${this.serverUrl}/rest/${endpoint}?${params.toString()}`;
    try {
      const resp = await fetch(url);
      if (!resp.ok) {
        throw new Error(`HTTP ${resp.status}: ${resp.statusText}`);
      }
      const data = await resp.json();
      const subResp = data["subsonic-response"];
      if (subResp && subResp.status === "failed") {
        throw new Error(subResp.error?.message || "Subsonic API request failed");
      }
      return subResp;
    } catch (err) {
      console.error(`[SubsonicAPI] Error on ${endpoint}:`, err);
      throw err;
    }
  }

  async ping() {
    return await this.request("ping.view");
  }

  async getStarred() {
    return await this.request("getStarred.view");
  }

  async getPlaylists() {
    return await this.request("getPlaylists.view");
  }

  async getPlaylist(id) {
    return await this.request("getPlaylist.view", { id });
  }

  async search3(query) {
    return await this.request("search3.view", { query, songCount: 50, albumCount: 20, artistCount: 20 });
  }

  async getAlbum(id) {
    return await this.request("getAlbum.view", { id });
  }

  async getArtist(id) {
    return await this.request("getArtist.view", { id });
  }

  getCoverArtUrl(id, size = 300) {
    if (!id) return "";
    const params = this._getAuthParams();
    params.append("id", id);
    params.append("size", size);
    return `${this.serverUrl}/rest/getCoverArt.view?${params.toString()}`;
  }

  getStreamUrl(id) {
    const params = this._getAuthParams();
    params.append("id", id);
    return `${this.serverUrl}/rest/stream.view?${params.toString()}`;
  }
}

window.api = new SubsonicAPI();
