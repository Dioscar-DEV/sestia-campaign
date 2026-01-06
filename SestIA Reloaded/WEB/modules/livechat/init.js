(function(){
    let state = {
        chatId: null,
        messages: [],
        conversation: null,
        loading: false,
        recentChats: []
    };

    let elements = {};

    async function init() {
        console.log('💬 Inicializando módulo Livechat...');

        // 1. Verificar permisos
        const hasView = window.App?.hasPerm && window.App.hasPerm('agent.livechat.view');
        if (!hasView) {
            renderAccessDenied();
            return;
        }

        // 2. Cargar estilos y preparar DOM
        await loadStyles();
        mapElements();
        bindEvents();

        // 3. Resolver chat_id inicial (si existe)
        state.chatId = getChatIdFromHash();

        // 4. Sin chat seleccionado → mostrar placeholder con sugerencias
        if (!state.chatId) {
            await showNoChatSelected();
            return;
        }

        // 5. Cargar datos del chat actual
        await loadChatData();
    }

    function mapElements() {
        elements = {
            container: document.getElementById('livechat-module'),
            messagesContainer: document.getElementById('livechat-messages'),
            title: document.getElementById('chat-title'),
            subtitle: document.getElementById('chat-subtitle'),
            avatar: document.getElementById('chat-avatar'),
            backBtn: document.getElementById('livechat-back-btn'),
            refreshBtn: document.getElementById('livechat-refresh-btn')
        };
    }

    function bindEvents() {
        if (elements.backBtn) {
            elements.backBtn.addEventListener('click', () => {
                window.location.hash = '#/contacts';
            });
        }
        if (elements.refreshBtn) {
            elements.refreshBtn.addEventListener('click', loadChatData);
        }
    }

    async function loadChatData() {
        state.chatId = getChatIdFromHash();
        if (!state.chatId) {
            await showNoChatSelected(true);
            return;
        }

        setLoading(true);
        try {
            state.conversation = null;
            state.messages = [];
            await Promise.all([
                fetchConversation(),
                fetchMessages()
            ]);
            renderHeader();
            renderMessages();
            scrollToBottom();
        } catch (err) {
            console.error('Error cargando chat:', err);
            const message = err?.message || 'No se pudo cargar la conversación.';
            renderError('Error cargando la conversación: ' + message);
        } finally {
            setLoading(false);
        }
    }

    async function fetchConversation() {
        const { supabase } = window.App;
        if (!supabase) {
            throw new Error('Supabase no está disponible.');
        }

        const query = supabase
            .schema('kpidata')
            .from('conversations')
            .select('*')
            .eq('chat_id', state.chatId)
            .limit(1);

        const response = typeof query.maybeSingle === 'function'
            ? await query.maybeSingle()
            : await query.single();

        if (response.error) throw response.error;
        if (!response.data) {
            throw new Error('La conversación no existe o ya no tienes acceso.');
        }

        state.conversation = response.data;
    }

    async function fetchMessages() {
        const { supabase } = window.App;
        if (!supabase) {
            throw new Error('Supabase no está disponible.');
        }

        const { data, error } = await supabase
            .schema('kpidata')
            .from('messages')
            .select('*')
            .eq('chat_id', state.chatId)
            .order('created_at', { ascending: true });

        if (error) throw error;
        state.messages = data || [];
    }

    function renderHeader() {
        if (!elements.title) return;
        if (!state.conversation) {
            setHeaderState('❔', 'Conversación no disponible', 'Verifica el contacto seleccionado.');
            return;
        }

        const title = state.conversation.title || 'Desconocido';
        setHeaderState(getInitials(title), title, `ID: ${state.chatId}`);
    }

    function renderMessages() {
        if (!elements.messagesContainer) return;
        elements.messagesContainer.innerHTML = '';

        if (state.messages.length === 0) {
            elements.messagesContainer.innerHTML = `
                <div class="chat-placeholder">
                    <div class="empty-icon">💬</div>
                    <p>No hay mensajes en esta conversación.</p>
                </div>
            `;
            return;
        }

        let lastDate = null;

        state.messages.forEach(msg => {
            // Separador de fecha
            const msgDate = new Date(msg.created_at).toLocaleDateString();
            if (msgDate !== lastDate) {
                const divider = document.createElement('div');
                divider.className = 'date-divider';
                divider.textContent = msgDate;
                elements.messagesContainer.appendChild(divider);
                lastDate = msgDate;
            }

            const bubble = createMessageBubble(msg);
            elements.messagesContainer.appendChild(bubble);
        });
    }

    function createMessageBubble(msg) {
        const el = document.createElement('div');
        el.className = `message-bubble role-${msg.role}`;
        
        let contentHtml = '';

        // Texto
        if (msg.content) {
            // Convertir saltos de línea a <br>
            const text = msg.content.replace(/\n/g, '<br>');
            contentHtml += `<div class="message-text">${text}</div>`;
        }

        // Multimedia
        if (msg.message_type !== 'text' && msg.media_url) {
            contentHtml += renderMediaContent(msg);
        }

        // Metadatos (hora)
        const time = new Date(msg.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        contentHtml += `
            <div class="message-meta">
                <span class="message-time">${time}</span>
            </div>
        `;

        el.innerHTML = contentHtml;
        return el;
    }

    function renderMediaContent(msg) {
        const url = msg.media_url; // Asumimos que viene firmada o es pública
        const type = msg.message_type;

        if (type === 'photo') {
            return `<div class="media-content"><img src="${url}" alt="Foto" loading="lazy" onclick="window.open('${url}', '_blank')"></div>`;
        }
        if (type === 'sticker') {
            return `<div class="media-content"><img src="${url}" alt="Sticker" class="media-sticker"></div>`;
        }
        if (type === 'voice' || type === 'audio') {
            return `<div class="media-content"><audio controls class="audio-player" src="${url}"></audio></div>`;
        }
        if (type === 'video') {
            return `<div class="media-content"><video controls src="${url}"></video></div>`;
        }
        if (type === 'document') {
            // Intentar extraer nombre del archivo de la URL o usar el tipo
            let filename = 'Documento adjunto';
            try {
                // Si es una URL de Supabase Storage, el nombre suele estar antes de los query params
                const path = url.split('?')[0];
                filename = path.split('/').pop();
            } catch (e) {}

            return `
                <div class="media-content">
                    <a href="${url}" target="_blank" class="file-attachment">
                        <span class="file-icon">📄</span>
                        <span class="file-name">${filename}</span>
                    </a>
                </div>
            `;
        }
        if (type === 'location') {
            // location content suele ser "lat|long"
            // media_url también trae "lat|long" en el ejemplo
            const coords = url.includes('|') ? url.replace('|', ',') : url;
            const mapUrl = `https://www.google.com/maps/search/?api=1&query=${coords}`;
            return `
                <div class="media-content">
                    <a href="${mapUrl}" target="_blank" class="location-preview">
                        📍 Ver ubicación: ${coords}
                    </a>
                </div>
            `;
        }

        return `<div class="media-content"><a href="${url}" target="_blank">Ver archivo adjunto (${type})</a></div>`;
    }

    function scrollToBottom() {
        if (elements.messagesContainer) {
            elements.messagesContainer.scrollTop = elements.messagesContainer.scrollHeight;
        }
    }

    function setLoading(isLoading) {
        state.loading = isLoading;
        if (!elements.messagesContainer) return;
        if (isLoading && elements.messagesContainer.childElementCount === 0) {
            elements.messagesContainer.innerHTML = `
                <div class="chat-placeholder">
                    <div class="spinner"></div>
                    <p>Cargando conversación...</p>
                </div>
            `;
        }
    }

    function renderError(msg) {
        setHeaderState('⚠️', 'Error al cargar el chat', 'Intenta nuevamente o selecciona otro contacto.');
        if (!elements.messagesContainer) return;

        const wrapper = document.createElement('div');
        wrapper.className = 'chat-placeholder error';

        const icon = document.createElement('div');
        icon.className = 'error-icon';
        icon.textContent = '⚠️';

        const text = document.createElement('p');
        text.textContent = msg;

        const buttons = document.createElement('div');
        buttons.className = 'error-actions';

        const retryBtn = document.createElement('button');
        retryBtn.className = 'btn-secondary';
        retryBtn.textContent = 'Reintentar';
        retryBtn.addEventListener('click', loadChatData);

        const contactsBtn = document.createElement('button');
        contactsBtn.className = 'btn-primary';
        contactsBtn.textContent = 'Ver Contactos';
        contactsBtn.addEventListener('click', () => {
            window.location.hash = '#/contacts';
        });

        buttons.append(retryBtn, contactsBtn);
        wrapper.innerHTML = '';
        wrapper.append(icon, text, buttons);

        elements.messagesContainer.innerHTML = '';
        elements.messagesContainer.appendChild(wrapper);
    }

    function renderAccessDenied() {
        const root = document.getElementById('livechat-module');
        if (root) {
            root.innerHTML = `
                <div class="state-message">
                    <div class="empty-icon">🔒</div>
                    <h3>Acceso Denegado</h3>
                    <p>No tienes permisos para ver el chat en vivo.</p>
                </div>
            `;
        }
    }

    function loadStyles() {
        return new Promise((resolve) => {
            const linkId = 'livechat-module-styles';
            if (document.getElementById(linkId)) return resolve();

            const link = document.createElement('link');
            link.id = linkId;
            link.rel = 'stylesheet';
            link.href = 'modules/livechat/styles.css';
            link.onload = resolve;
            document.head.appendChild(link);
        });
    }

    async function showNoChatSelected(forceReload = false) {
        state.conversation = null;
        state.messages = [];
        setHeaderState('💬', 'Selecciona un chat', 'Abre Contactos y usa "Ver Chat" para cargar una conversación.');

        if (elements.messagesContainer) {
            elements.messagesContainer.innerHTML = `
                <div class="chat-placeholder">
                    <div class="empty-icon">💬</div>
                    <h3>Sin conversación seleccionada</h3>
                    <p>Abre el módulo de Contactos para elegir un usuario o selecciona una conversación reciente.</p>
                    <button class="btn-primary" id="livechat-go-contacts">Ir a Contactos</button>
                    <div class="recent-chats" id="livechat-recent-chats"></div>
                </div>
            `;

            document.getElementById('livechat-go-contacts')?.addEventListener('click', () => {
                window.location.hash = '#/contacts';
            });
        }

        await loadRecentChatsPreview(forceReload);
    }

    async function loadRecentChatsPreview(forceReload = false) {
        const wrapper = document.getElementById('livechat-recent-chats');
        if (!wrapper) return;

        if (!forceReload && state.recentChats.length) {
            renderRecentChatsList(wrapper, state.recentChats);
            return;
        }

        wrapper.innerHTML = '<p class="recent-empty">Cargando conversaciones recientes...</p>';
        try {
            const { supabase } = window.App;
            if (!supabase) throw new Error('Supabase no está disponible.');

            const { data, error } = await supabase
                .schema('kpidata')
                .from('conversations')
                .select('chat_id, title, updated_at, created_at')
                .order('updated_at', { ascending: false })
                .order('created_at', { ascending: false })
                .limit(5);

            if (error) throw error;
            state.recentChats = data || [];
            renderRecentChatsList(wrapper, state.recentChats);
        } catch (err) {
            console.error('No se pudieron cargar conversaciones recientes:', err);
            wrapper.innerHTML = '<p class="recent-empty error">No se pudieron cargar las conversaciones recientes.</p>';
        }
    }

    function renderRecentChatsList(container, chats) {
        if (!container) return;
        const safeChats = (chats || []).filter(chat => !!chat?.chat_id);
        if (!safeChats.length) {
            container.innerHTML = '<p class="recent-empty">Aún no hay conversaciones registradas.</p>';
            return;
        }

        container.innerHTML = safeChats.map(chat => {
            const title = chat.title || 'Sin título';
            const meta = formatTimestamp(chat.updated_at || chat.created_at);
            return `
                <button class="recent-chat-card" data-chat="${chat.chat_id}">
                    <div class="chat-avatar-sm">${getInitials(title)}</div>
                    <div class="recent-chat-info">
                        <strong>${title}</strong>
                        <span>${meta}</span>
                    </div>
                </button>
            `;
        }).join('');

        container.querySelectorAll('.recent-chat-card').forEach(btn => {
            btn.addEventListener('click', () => {
                const chatId = btn.getAttribute('data-chat');
                if (chatId) {
                    window.location.hash = `#/livechat?chat_id=${encodeURIComponent(chatId)}`;
                }
            });
        });
    }

    function setHeaderState(initials, titleText, subtitleText) {
        if (elements.avatar) {
            elements.avatar.textContent = initials || '💬';
        }
        if (elements.title) {
            elements.title.textContent = titleText || 'Livechat';
        }
        if (elements.subtitle) {
            elements.subtitle.textContent = subtitleText || '';
        }
    }

    function formatTimestamp(value) {
        if (!value) return 'Sin registro';
        try {
            return new Date(value).toLocaleString();
        } catch (err) {
            return value;
        }
    }

    function getInitials(text) {
        if (!text) return '??';
        return text.trim().substring(0, 2).toUpperCase();
    }

    function getChatIdFromHash() {
        const rawHash = window.location.hash || '';
        const cleaned = rawHash.replace(/^#\/?/, '');
        const parts = cleaned.split('?');
        if (parts.length < 2) {
            return null;
        }
        const queryPart = parts.slice(1).join('?');
        const sanitized = queryPart.split('#')[0];
        const params = new URLSearchParams(sanitized);
        const value = params.get('chat_id');
        return value ? value.trim() : null;
    }

    window.LivechatModule = { init };
})();
