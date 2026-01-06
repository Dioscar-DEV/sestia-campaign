(function(){
    // Referencias a elementos del DOM
    let elements = {
        container: null,
        list: null,
        loading: null,
        empty: null,
        searchInput: null,
        refreshBtn: null,
        modal: null,
        modalCloseBtn: null,
        modalCloseIcon: null
    };

    let state = {
        contacts: [],
        filter: ''
    };

    let fallbackBackdrop = null;

    // Inicializador del módulo
    async function init() {
        console.log('📇 Inicializando módulo de Contactos...');

        // 0. Verificar permisos
        const hasView = window.App?.hasPerm && window.App.hasPerm('agent.contacts.view');
        if (!hasView) {
            const root = document.getElementById('contacts-module');
            if (root) {
                root.innerHTML = `
                    <div class="state-message">
                        <div class="empty-icon">🔒</div>
                        <h3>Acceso Denegado</h3>
                        <p>No tienes permisos para ver los contactos del agente.</p>
                    </div>
                `;
            }
            return;
        }
        
        // 1. Cargar estilos dinámicamente
        await loadStyles();

        // 2. Mapear elementos del DOM
        mapElements();

        // 3. Bindear eventos
        bindEvents();

        // 4. Cargar datos iniciales
        await fetchContacts();
    }

    function loadStyles() {
        return new Promise((resolve) => {
            const linkId = 'contacts-module-styles';
            if (document.getElementById(linkId)) return resolve();

            const link = document.createElement('link');
            link.id = linkId;
            link.rel = 'stylesheet';
            link.href = 'modules/contacts/styles.css';
            link.onload = resolve;
            document.head.appendChild(link);
        });
    }

    function mapElements() {
        const root = document.getElementById('contacts-module');
        if (!root) return;

        elements = {
            container: root,
            list: document.getElementById('contacts-grid'),
            loading: document.getElementById('contacts-loading'),
            empty: document.getElementById('contacts-empty'),
            searchInput: document.getElementById('contacts-search-input'),
            refreshBtn: document.getElementById('contacts-refresh-btn'),
            modal: document.getElementById('contacts-detail-modal'),
            modalCloseBtn: document.getElementById('contacts-modal-close-btn'),
            modalCloseIcon: document.getElementById('contacts-modal-close'),
            
            // Modal fields
            mTitle: document.getElementById('modal-contact-name'),
            mAvatar: document.getElementById('modal-avatar'),
            mNickname: document.getElementById('modal-nickname'),
            mChannel: document.getElementById('modal-channel'),
            mRealname: document.getElementById('modal-realname'),
            mPhone: document.getElementById('modal-phone'),
            mEmail: document.getElementById('modal-email'),
            mUserid: document.getElementById('modal-userid'),
            mVerified: document.getElementById('modal-verified'),
            mFriendshipBar: document.getElementById('modal-friendship-bar'),
            mFriendshipVal: document.getElementById('modal-friendship-val'),
            mLastSeen: document.getElementById('modal-last-seen')
        };
    }

    function bindEvents() {
        if (elements.searchInput) {
            elements.searchInput.addEventListener('input', (e) => {
                state.filter = e.target.value.toLowerCase();
                renderList();
            });
        }

        if (elements.refreshBtn) {
            elements.refreshBtn.addEventListener('click', fetchContacts);
        }

        if (elements.modalCloseBtn) elements.modalCloseBtn.addEventListener('click', closeModal);
        if (elements.modalCloseIcon) elements.modalCloseIcon.addEventListener('click', closeModal);
        
        // Cerrar modal al hacer click fuera
        if (elements.modal) {
            elements.modal.addEventListener('click', (e) => {
                if (e.target === elements.modal) closeModal();
            });
        }
    }

    async function fetchContacts() {
        setLoading(true);
        try {
            const { supabase } = window.App;
            if (!supabase) throw new Error('Supabase no inicializado');

            // Consulta a la tabla agent_contact_list en el esquema instancias
            const { data, error } = await supabase
                .schema('instancias')
                .from('agent_contact_list')
                .select('*')
                .order('created_at', { ascending: false });

            if (error) throw error;

            state.contacts = data || [];
            console.log(`📇 ${state.contacts.length} contactos cargados.`);
            renderList();

        } catch (err) {
            console.error('❌ Error cargando contactos:', err);
            alert('Error al cargar contactos: ' + err.message);
        } finally {
            setLoading(false);
        }
    }

    function renderList() {
        if (!elements.list) return;

        elements.list.innerHTML = '';
        
        const filtered = state.contacts.filter(c => {
            const searchStr = `${c.contact_nickname || ''} ${c.contact_name || ''} ${c.contact_phone || ''} ${c.contact_email || ''}`.toLowerCase();
            return searchStr.includes(state.filter);
        });

        if (filtered.length === 0) {
            elements.list.classList.add('hidden');
            elements.empty.classList.remove('hidden');
            return;
        }

        elements.empty.classList.add('hidden');
        elements.list.classList.remove('hidden');

        filtered.forEach(contact => {
            const card = createContactCard(contact);
            elements.list.appendChild(card);
        });
    }

    function createContactCard(contact) {
        const el = document.createElement('div');
        el.className = 'contact-card';
        el.onclick = () => openModal(contact);

        const initials = getInitials(contact.contact_nickname || contact.contact_name || '?');
        const displayName = contact.contact_nickname || contact.contact_name || 'Sin Nombre';
        const channel = contact.contact_channel || 'Desconocido';
        const identifier = contact.contact_phone || contact.contact_email || contact.user_id;

        el.innerHTML = `
            <div class="card-avatar">${initials}</div>
            <div class="card-info">
                <div class="card-header">
                    <h4 class="card-name" title="${displayName}">${displayName}</h4>
                    <span class="card-channel-badge">${channel}</span>
                </div>
                <p class="card-detail" title="${identifier}">${identifier}</p>
                <div class="card-meta">
                    <span class="meta-item">
                        <span>❤️</span> ${contact.contact_friendship || 0}
                    </span>
                    <span class="meta-item">
                        <span>💬</span> ${contact.contact_prompt_count || 0}
                    </span>
                </div>
            </div>
        `;
        return el;
    }

    function openModal(contact) {
        if (!elements.modal) return;

        // Popular datos
        const initials = getInitials(contact.contact_nickname || contact.contact_name || '?');
        if (elements.mTitle) {
            elements.mTitle.textContent = contact.contact_nickname || contact.contact_name || 'Contacto';
        }
        elements.mAvatar.textContent = initials;
        elements.mNickname.textContent = contact.contact_nickname || 'Sin Nickname';
        elements.mChannel.textContent = contact.contact_channel || '-';
        
        elements.mRealname.textContent = contact.contact_name || '-';
        elements.mPhone.textContent = contact.contact_phone || '-';
        elements.mEmail.textContent = contact.contact_email || '-';
        elements.mUserid.textContent = contact.user_id || '-';
        
        elements.mVerified.textContent = contact.contact_verify ? '✅ Sí' : '❌ No';
        
        const friendship = contact.contact_friendship || 0;
        elements.mFriendshipVal.textContent = friendship;
        // Asumiendo un max de 100 para la barra, ajustar según lógica de negocio
        const pct = Math.min(Math.max(friendship, 0), 100); 
        elements.mFriendshipBar.style.width = `${pct}%`;

        elements.mLastSeen.textContent = contact.created_at ? new Date(contact.created_at).toLocaleString() : '-';

        // Botón Ver Chat
        const chatBtn = document.getElementById('modal-chat-btn');
        if (chatBtn) {
            chatBtn.onclick = null;
            chatBtn.disabled = false;
            chatBtn.title = '';
            // Verificar permiso para ver el botón
            const hasChatPerm = window.App?.hasPerm && window.App.hasPerm('agent.livechat.view');
            if (hasChatPerm && contact.contact_chat) {
                chatBtn.style.display = 'inline-flex';
                chatBtn.disabled = false;
                chatBtn.onclick = () => {
                    closeModal();
                    // Usar contact_chat como ID de conversación
                    window.location.hash = `#/livechat?chat_id=${encodeURIComponent(contact.contact_chat)}`;
                };
            } else if (hasChatPerm) {
                chatBtn.style.display = 'inline-flex';
                chatBtn.disabled = true;
                chatBtn.title = 'Este contacto aún no tiene un chat asociado.';
            } else {
                chatBtn.style.display = 'none';
            }
        }

        // Mostrar modal
        if (typeof elements.modal.showModal === 'function') {
            toggleFallbackBackdrop(false);
            elements.modal.showModal();
        } else {
            elements.modal.setAttribute('open', '');
            elements.modal.classList.add('open');
            toggleFallbackBackdrop(true);
        }
    }

    function closeModal() {
        if (!elements.modal) return;
        if (typeof elements.modal.close === 'function') {
            elements.modal.close();
        } else {
            elements.modal.removeAttribute('open');
            elements.modal.classList.remove('open');
        }
        toggleFallbackBackdrop(false);
    }

    function setLoading(isLoading) {
        if (isLoading) {
            elements.loading.classList.remove('hidden');
            elements.list.classList.add('hidden');
            elements.empty.classList.add('hidden');
        } else {
            elements.loading.classList.add('hidden');
        }
    }

    function getInitials(name) {
        return name.substring(0, 2).toUpperCase();
    }

    function toggleFallbackBackdrop(show) {
        if (show) {
            if (!fallbackBackdrop || !document.body.contains(fallbackBackdrop)) {
                fallbackBackdrop = document.createElement('div');
                fallbackBackdrop.className = 'contacts-modal-backdrop';
                fallbackBackdrop.addEventListener('click', closeModal);
                document.body.appendChild(fallbackBackdrop);
            }
            fallbackBackdrop.classList.add('visible');
            document.body.style.overflow = 'hidden';
        } else if (fallbackBackdrop) {
            fallbackBackdrop.classList.remove('visible');
            document.body.style.overflow = '';
        }
    }

    // Exponer API pública del módulo
    window.ContactsModule = {
        init: init
    };
})();
