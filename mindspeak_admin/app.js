(() => {
  const apiRoot = "/api/v1/admin";
  const tokenKey = "mindspeak.admin.session";
  const loginPanel = document.querySelector("#loginPanel");
  const dashboardPanel = document.querySelector("#dashboardPanel");
  const loginForm = document.querySelector("#loginForm");
  const loginButton = document.querySelector("#loginButton");
  const loginError = document.querySelector("#loginError");
  const adminIdentity = document.querySelector("#adminIdentity");
  const userRows = document.querySelector("#userRows");
  const usersError = document.querySelector("#usersError");
  const resultSummary = document.querySelector("#resultSummary");
  const pageIndicator = document.querySelector("#pageIndicator");
  const previousPage = document.querySelector("#previousPage");
  const nextPage = document.querySelector("#nextPage");
  const searchInput = document.querySelector("#userSearch");
  const sortDateButton = document.querySelector("#sortDateButton");
  const sortGlyph = document.querySelector("#sortGlyph");

  let token = sessionStorage.getItem(tokenKey);
  let currentPage = 1;
  let pageSize = 10;
  let sortDirection = "desc";
  let searchTimer;

  async function request(path, { method = "GET", body } = {}) {
    const headers = { Accept: "application/json" };
    if (body !== undefined) headers["Content-Type"] = "application/json";
    if (token && path !== "/auth/login") headers.Authorization = `Bearer ${token}`;

    let response;
    try {
      response = await fetch(`${apiRoot}${path}`, {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
        cache: "no-store",
      });
    } catch (_) {
      throw new Error("Could not reach the MindSpeak server. Check that FastAPI is running.");
    }

    let payload = {};
    try { payload = await response.json(); } catch (_) { /* Use a safe fallback below. */ }
    if (!response.ok) {
      if (response.status === 401 && path !== "/auth/login") clearSession("Your session expired. Sign in again.");
      const detail = payload.detail;
      const message = detail && typeof detail === "object" ? detail.message : null;
      throw new Error(typeof message === "string" ? message : "The request could not be completed.");
    }
    return payload;
  }

  function showLogin(message = "") {
    dashboardPanel.hidden = true;
    loginPanel.hidden = false;
    loginError.textContent = message;
    loginError.hidden = !message;
  }

  function showDashboard(admin) {
    loginPanel.hidden = true;
    dashboardPanel.hidden = false;
    adminIdentity.textContent = admin?.email ?? "Administrator";
  }

  function clearSession(message = "") {
    token = null;
    sessionStorage.removeItem(tokenKey);
    document.querySelector("#totalUsers").textContent = "—";
    document.querySelector("#verifiedUsers").textContent = "—";
    document.querySelector("#newUsers").textContent = "—";
    document.querySelector("#verificationRate").textContent = "—";
    adminIdentity.textContent = "";
    searchInput.value = "";
    currentPage = 1;
    resultSummary.textContent = "No users loaded";
    pageIndicator.textContent = "Page 1";
    previousPage.disabled = true;
    nextPage.disabled = true;
    usersError.hidden = true;
    setTableMessage("Sign in to load users.");
    showLogin(message);
  }

  function setTableMessage(message) {
    userRows.replaceChildren();
    const row = document.createElement("tr");
    const cell = document.createElement("td");
    cell.colSpan = 5;
    cell.className = "table-state";
    cell.textContent = message;
    row.append(cell);
    userRows.append(row);
  }

  function dateLabel(value) {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return "—";
    return new Intl.DateTimeFormat(undefined, { year: "numeric", month: "short", day: "numeric" }).format(date);
  }

  function renderUsers(users) {
    userRows.replaceChildren();
    if (!users.length) {
      setTableMessage(searchInput.value.trim() ? "No users match this search." : "No registered users yet.");
      return;
    }

    const fragment = document.createDocumentFragment();
    for (const user of users) {
      const row = document.createElement("tr");
      const name = document.createElement("td");
      name.className = "name-cell";
      name.textContent = user.name;
      const email = document.createElement("td");
      email.textContent = user.email;
      const id = document.createElement("td");
      id.className = "id-cell";
      id.textContent = `#${user.id}`;
      const created = document.createElement("td");
      created.textContent = dateLabel(user.created_at);
      const statusCell = document.createElement("td");
      const badge = document.createElement("span");
      badge.className = `status-pill ${user.email_verified ? "status-verified" : "status-pending"}`;
      badge.textContent = user.email_verified ? "Verified" : "Pending";
      statusCell.append(badge);
      row.append(name, email, id, created, statusCell);
      fragment.append(row);
    }
    userRows.append(fragment);
  }

  async function loadStats() {
    const stats = await request("/dashboard/stats");
    document.querySelector("#totalUsers").textContent = stats.total_users.toLocaleString();
    document.querySelector("#verifiedUsers").textContent = stats.verified_users.toLocaleString();
    document.querySelector("#newUsers").textContent = stats.new_registrations_7d.toLocaleString();
    document.querySelector("#verificationRate").textContent = `${Number(stats.email_verification_rate).toFixed(1)}%`;
  }

  async function loadUsers() {
    usersError.hidden = true;
    setTableMessage("Loading users…");
    resultSummary.textContent = "Loading…";
    const params = new URLSearchParams({ page: String(currentPage), page_size: String(pageSize), sort: sortDirection });
    const query = searchInput.value.trim();
    if (query) params.set("q", query);

    try {
      const result = await request(`/users?${params.toString()}`);
      renderUsers(result.users);
      const start = result.total === 0 ? 0 : (result.page - 1) * result.page_size + 1;
      const end = Math.min(result.page * result.page_size, result.total);
      resultSummary.textContent = result.total ? `Showing ${start}–${end} of ${result.total} users` : "0 users";
      const pageCount = Math.max(1, Math.ceil(result.total / result.page_size));
      pageIndicator.textContent = `Page ${result.page} of ${pageCount}`;
      previousPage.disabled = result.page <= 1;
      nextPage.disabled = result.page >= pageCount;
    } catch (error) {
      if (!token) return;
      usersError.textContent = error.message;
      usersError.hidden = false;
      setTableMessage("User data could not be loaded.");
      resultSummary.textContent = "Unable to load users";
    }
  }

  async function loadDashboard() {
    usersError.hidden = true;
    try {
      await Promise.all([loadStats(), loadUsers()]);
    } catch (error) {
      usersError.textContent = error.message;
      usersError.hidden = false;
      if (!token) return;
    }
  }

  loginForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    loginError.hidden = true;
    loginButton.disabled = true;
    loginButton.textContent = "Signing in…";
    const form = new FormData(loginForm);
    try {
      const result = await request("/auth/login", {
        method: "POST",
        body: { email: String(form.get("email")).trim(), password: String(form.get("password")) },
      });
      token = result.access_token;
      sessionStorage.setItem(tokenKey, token);
      loginForm.reset();
      showDashboard(result.admin);
      await loadDashboard();
    } catch (error) {
      loginError.textContent = error.message;
      loginError.hidden = false;
    } finally {
      loginButton.disabled = false;
      loginButton.textContent = "Sign in";
    }
  });

  document.querySelector("#logoutButton").addEventListener("click", () => clearSession());
  previousPage.addEventListener("click", () => {
    if (currentPage > 1) { currentPage -= 1; void loadUsers(); }
  });
  nextPage.addEventListener("click", () => {
    currentPage += 1;
    void loadUsers();
  });
  searchInput.addEventListener("input", () => {
    window.clearTimeout(searchTimer);
    searchTimer = window.setTimeout(() => { currentPage = 1; void loadUsers(); }, 250);
  });
  sortDateButton.addEventListener("click", () => {
    sortDirection = sortDirection === "desc" ? "asc" : "desc";
    sortGlyph.textContent = sortDirection === "desc" ? "↓" : "↑";
    sortDateButton.setAttribute("aria-label", `Sort by registration date, ${sortDirection === "desc" ? "newest" : "oldest"} first`);
    currentPage = 1;
    void loadUsers();
  });

  async function restoreSession() {
    if (!token) return;
    try {
      const admin = await request("/auth/me");
      showDashboard(admin);
      await loadDashboard();
    } catch (_) {
      clearSession("Please sign in to continue.");
    }
  }

  void restoreSession();
})();
