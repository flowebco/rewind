'use strict';
const sanitizeInput = str => str.replace(/[<>'"]/g, '').trim();
function scheduleIdleTask(cb) { if (typeof scheduler !== 'undefined' && scheduler.yield) return scheduler.yield().then(cb); if (typeof requestIdleCallback !== 'undefined') return new Promise(resolve => requestIdleCallback(() => { cb(); resolve(); })); return new Promise(resolve => setTimeout(() => { cb(); resolve(); }, 0)); }

class AIAgent {
    #headers = {
        'Authorization': `Bearer tpsg-xqXL4lnID8Y46aB7B1eZp1H8qUajfFC`,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    };

    constructor(config) {
        this.botId = config.botId; this.storageKey = config.storageKey || 'ai_session'; this.pendingQuestion = config.ask || null; this.onError = config.onError || console.error; this.sessionId = null; this.userId = null; this.userName = null; this.isReady = false; this.messages = [];
    }
    loadFromStorage() { const stored = localStorage.getItem(this.storageKey); if (!stored) return null; try { const data = JSON.parse(stored); this.sessionId = data.sessionId; this.userId = data.userId; this.userName = data.userName; this.messages = data.messages || []; return data; } catch (e) { this.onError(e); return null; } }
    saveToStorage() { if (!this.sessionId) { localStorage.removeItem(this.storageKey); return; } localStorage.setItem(this.storageKey, JSON.stringify({ sessionId: this.sessionId, userId: this.userId, userName: this.userName, messages: this.messages })); }
    addMessage(text, sender, isHidden = false) { this.messages.push({ text, sender, isHidden }); this.saveToStorage(); }
    resetSession() { this.sessionId = null; this.userId = null; this.userName = null; this.isReady = false; this.messages = []; localStorage.removeItem(this.storageKey); }
    async _createSession(userInfo) { const payload = { botId: this.botId }; if (userInfo) { payload.user = { id: userInfo.id, name: userInfo.name }; this.userId = userInfo.id; this.userName = userInfo.name; } const response = await fetch('https://api.metisai.ir/api/v1/chat/session', { method: 'POST', headers: this.#headers, body: JSON.stringify(payload), signal: AbortSignal.timeout(20000) }); if (!response.ok) throw new Error(`Create session failed (${response.status})`); const data = await response.json(); this.sessionId = data.id; this.saveToStorage(); this.isReady = true; return data; }
    async _sendRawMessage(text) { if (!this.sessionId) throw new Error('NO_SESSION'); const response = await fetch(`https://api.metisai.ir/api/v1/chat/session/${this.sessionId}/message`, { method: 'POST', headers: this.#headers, body: JSON.stringify({ message: { content: text, type: 'USER' } }), signal: AbortSignal.timeout(30000) }); if (!response.ok) { if (response.status === 400 || response.status === 404) { this.resetSession(); throw new Error('SESSION_EXPIRED'); } throw new Error(`HTTP ${response.status}`); } const data = await response.json(); return data.content || ''; }
    async #tryResumeSession() { const stored = this.loadFromStorage(); if (!stored || !stored.sessionId) return false; try { await this._sendRawMessage('ping'); this.isReady = true; return true; } catch (err) { if (err.message === 'SESSION_EXPIRED') this.resetSession(); return false; } }
    async authenticate(userInfo) { if (this.isReady && this.sessionId) return true; if (await this.#tryResumeSession()) return true; await this._createSession(userInfo); this.isReady = true; return true; }
    async _ensureAuthenticated() { if (this.isReady && this.sessionId) return; if (await this.#tryResumeSession()) return; const userInfo = getGlobalUser(); if (!userInfo || !userInfo.id || !userInfo.name) throw new Error('User not authenticated globally yet.'); await this.authenticate(userInfo); }
    async ask(question) { await this._ensureAuthenticated(); let qToAsk = question; if (this.pendingQuestion) { qToAsk = this.pendingQuestion; this.pendingQuestion = null; } return await this._sendRawMessage(qToAsk); }
    logout() { this.resetSession(); }
}

const supportContainer = document.getElementById('support-morph-container');
const chatWindowContent = document.getElementById('chat-window-content');
const authWindowContent = document.getElementById('auth-window-content');
const authNameInput = document.getElementById('authName');
const authPhoneInput = document.getElementById('authPhone');
let activeTrigger = null, activeProductName = null, previousTrigger = null;

function getGlobalUser() { try { const data = localStorage.getItem('global_auth_user'); return data ? JSON.parse(data) : null; } catch (e) { return null; } }
function setGlobalUser(user) { localStorage.setItem('global_auth_user', JSON.stringify(user)); }
const agents = {}; let activeAgent = null;

function appendMessage(text, sender, isLoading = false) { const div = document.createElement('div'); div.className = `chat-bubble ${sender}`; if (isLoading) div.id = 'loadingBubble'; let formattedText = text; formattedText = formattedText.replace(/\*\*(.*?)\*\*/g, '<strong class="accent-text" style="font-weight: 800;">$1</strong>'); formattedText = formattedText.replace(/\n/g, '<br>'); div.innerHTML = formattedText; chatMessages.appendChild(div); chatMessages.scrollTop = chatMessages.scrollHeight; }
function removeLoadingBubble() { const loader = document.getElementById('loadingBubble'); if (loader) loader.remove(); }

async function handleSendMessage(text, isAuto = false) { if (!text && !isAuto) return; if (!activeAgent) return; if (!isAuto) { appendMessage(text, 'user'); activeAgent.addMessage(text, 'user'); chatInput.value = ''; } else { activeAgent.addMessage(activeAgent.pendingQuestion || text, 'user', true); } appendMessage('<div class="typing-indicator"><span></span><span></span><span></span></div>', 'ai', true); try { const response = await activeAgent.ask(text); removeLoadingBubble(); appendMessage(response, 'ai'); activeAgent.addMessage(response, 'ai'); } catch (e) { removeLoadingBubble(); appendMessage('Ų®Ų·Ų§ ŲÆŲ± Ų§Ų±ŲŖŲØŲ§Ų·. Ł„Ų·ŁŲ§Ł‹ Ł…Ų¬ŲÆŲÆŲ§Ł‹ ŲŖŁ„Ų§Ų´ Ł†Ł…Ų§ŪŪŲÆ.', 'ai'); console.error('Chat error:', e); } }

function openChatFor(productName = null) {
    const agentKey = productName || 'general';
    if (!agents[agentKey]) agents[agentKey] = new AIAgent({ botId: 'd9408e23-2e44-431c-807a-290c72039d46', storageKey: 'support_chat_' + agentKey });
    activeAgent = agents[agentKey];
    chatMessages.innerHTML = '';
    activeAgent.loadFromStorage();
    if (activeAgent.messages && activeAgent.messages.length > 0) {
        scheduleIdleTask(() => { activeAgent.messages.forEach((msg, i) => { if (i % 5 === 0 && typeof scheduler !== 'undefined' && scheduler.yield) scheduler.yield(); if (!msg.isHidden) appendMessage(msg.text, msg.sender); }); });
    } else {
        if (productName) {
            const systemPrompt = `Ų³Ł„Ų§Ł…. Ł…Ł† ŲØŁ‡ Ų¹Ł†ŁŲ§Ł† Ś©Ų§Ų±ŲØŲ± Ų³Ų§ŪŲŖ Ł¾Ų§Ł„Ł¾ Ų§ŪŲ±Ų§Ł†Ų ŲÆŲ±ŲØŲ§Ų±Ł‡ Ł…Ų­ŲµŁŁ„ '${productName}' Ł†ŪŲ§Ų² ŲØŁ‡ Ł…Ų´Ų§ŁŲ±Ł‡ ŲÆŲ§Ų±Ł…. Ų´Ł…Ų§ ŲØŁ‡ Ų¹Ł†ŁŲ§Ł† Ł…Ų´Ų§ŁŲ± ŁŲ±ŁŲ´ Ų´Ų±Ś©ŲŖ Ł¾Ų§Ł„Ł¾ Ų§ŪŲ±Ų§Ł†Ų Ł„Ų·ŁŲ§Ł‹ Ų¶Ł…Ł† Ų§Ų±Ų§Ų¦Ł‡ ŪŚ© Ų³Ł„Ų§Ł… Ł ŁŁ‚ŲŖā€ŲØŲ®ŪŲ± ŚÆŲ±Ł…Ų ŲØŁ‡ ŲµŁŲ±ŲŖ Ł…Ų®ŲŖŲµŲ± Ł Ł…ŁŪŲÆ Ų§Ų·Ł„Ų§Ų¹Ų§ŲŖ Ų§ŁŁ„ŪŁ‡ Ł Ł…Ų²Ų§ŪŲ§Ū Ų§ŪŁ† Ł…Ų­ŲµŁŁ„ Ų±Ų§ ŲØŁ‡ Ł…Ł† Ų§Ų±Ų§Ų¦Ł‡ ŲØŲÆŁ‡. Ų³Ł¾Ų³ Ł…Ł†ŲŖŲøŲ± ŲØŁ…Ų§Ł† Ł Ų§Ų² Ł…Ł† ŲØŁ¾Ų±Ų³ Ś©Ł‡ Ś†Ł‡ Ų³ŁŲ§Ł„Ų§ŲŖŪ ŲÆŲ±ŲØŲ§Ų±Ł‡ Ł‚ŪŁ…ŲŖŲ Ų´Ų±Ų§ŪŲ· ŁŁ†Ū ŪŲ§ Ł†ŲµŲØ ŲÆŲ§Ų±Ł… ŲŖŲ§ Ł…Ų±Ų§ Ų±Ų§Ł‡Ł†Ł…Ų§ŪŪ Ś©Ł†Ū.`;
            activeAgent.pendingQuestion = systemPrompt;
            handleSendMessage('', true);
        } else {
            const welcomeMsg = 'Ų³Ł„Ų§Ł…! Ś†Ų·ŁŲ± Ł…Ūā€ŲŖŁŲ§Ł†Ł… ŲÆŲ± Ł…ŁŲ±ŲÆ Ų±Ų§Ł‡ā€Ų§Ł†ŲÆŲ§Ų²Ū Ų®Ų· ŲŖŁŁ„ŪŲÆ ŲØŁ‡ Ų´Ł…Ų§ Ś©Ł…Ś© Ś©Ł†Ł…Ų';
            activeAgent.addMessage(welcomeMsg, 'ai');
            appendMessage(welcomeMsg, 'ai');
        }
    }
}

function safeViewTransition(updateCallback) {
    if (!document.startViewTransition) { updateCallback(); return { finished: Promise.resolve() }; }
    document.body.classList.add('is-morphing');
    const t = document.startViewTransition(updateCallback);
    t.finished.catch(e => console.warn('View Transition failed:', e)).finally(() => {
        document.body.classList.remove('is-morphing');
    });
    return t;
}

function openSupportFor(triggerEl, dialogClass, contentMode) {
    if (previousTrigger) previousTrigger.style.viewTransitionName = 'none';
    activeTrigger = triggerEl;
    previousTrigger = triggerEl;

    // Force layout flush for accurate View Transition snapshot
    triggerEl.getBoundingClientRect();

    triggerEl.style.viewTransitionName = 'support-morph';
    supportContainer.style.viewTransitionName = 'none';
    safeViewTransition(() => {
        triggerEl.style.viewTransitionName = 'none';
        if (triggerEl.id === 'ai-agent-btn') triggerEl.style.display = 'none';
        supportContainer.style.viewTransitionName = 'support-morph';
        supportContainer.className = dialogClass;
        if (!supportContainer.matches(':popover-open')) supportContainer.showPopover();
        authWindowContent.style.display = contentMode === 'auth' ? 'flex' : 'none';
        chatWindowContent.style.display = contentMode === 'chat' ? 'flex' : 'none';
        if (contentMode === 'chat') {
            openChatFor(activeProductName);
        }
    });
}

function closeSupport() {
    if (!activeTrigger) return;
    supportContainer.style.viewTransitionName = 'support-morph';
    activeTrigger.style.viewTransitionName = 'none';
    safeViewTransition(() => {
        supportContainer.style.viewTransitionName = 'none';
        supportContainer.hidePopover();
        if (activeTrigger && activeTrigger.id === 'ai-agent-btn') activeTrigger.style.display = 'grid';
        if (activeTrigger) activeTrigger.style.viewTransitionName = 'support-morph';
    }).finished.then(() => {
        if (activeTrigger) { activeTrigger.style.viewTransitionName = 'none'; activeTrigger = null; }
    });
}

// One delegated listener replaces five separate click handlers (3x product-cta,
// ai-agent-btn, 2x close buttons). The native Invoker Commands API fires this
// "command" event on the popover target itself and hands us event.source
// (the exact button that was activated), so we no longer track that manually.
supportContainer.addEventListener('command', (event) => {
    event.preventDefault();
    const trigger = event.source;
    if (event.command === 'hide-popover') { closeSupport(); return; }
    const isAuthNeeded = !getGlobalUser();
    if (trigger.id === 'ai-agent-btn') {
        activeProductName = null;
        openSupportFor(trigger, isAuthNeeded ? 'chat-dialog-auth' : 'chat-dialog-fab', isAuthNeeded ? 'auth' : 'chat');
    } else if (trigger.classList.contains('product-cta')) {
        activeProductName = trigger.dataset.product;
        openSupportFor(trigger, isAuthNeeded ? 'chat-dialog-auth' : 'chat-dialog-center', isAuthNeeded ? 'auth' : 'chat');
    }
});

authForm.addEventListener('submit', (event) => {
    event.preventDefault(); // native `required` validation already gated this submit
    const name = sanitizeInput(authNameInput.value);
    const phone = sanitizeInput(authPhoneInput.value);
    setGlobalUser({ id: phone, name: name });

    const executeAuthToChatDOM = () => {
        supportContainer.classList.remove('chat-dialog-auth');
        const isFAB = activeTrigger && activeTrigger.id === 'ai-agent-btn';
        supportContainer.classList.add(isFAB ? 'chat-dialog-fab' : 'chat-dialog-center');
        authWindowContent.style.display = 'none';
        chatWindowContent.style.display = 'flex';
        openChatFor(activeProductName);
    };

    if (!document.startViewTransition) { executeAuthToChatDOM(); return; }
    supportContainer.style.viewTransitionName = 'support-morph';
    const transition = safeViewTransition(executeAuthToChatDOM);
    transition.finished.finally(() => { supportContainer.style.viewTransitionName = ''; });
});

chatForm.addEventListener('submit', (event) => {
    event.preventDefault();
    handleSendMessage(chatInput.value.trim());
});