// Función global para seleccionar elementos por id
function qs(id){ return document.getElementById(id); }
// Función global para logs visuales
function addLog(message, type = 'info') {
  const logContainer = document.getElementById('wsp-loading-logs');
  if(!logContainer) return;
  const timestamp = new Date().toLocaleTimeString('es-ES');
  const icon = type === 'error' ? '❌' : type === 'success' ? '✅' : type === 'warning' ? '⚠️' : '🔵';
  const color = type === 'error' ? '#dc2626' : type === 'success' ? '#16a34a' : type === 'warning' ? '#ea580c' : '#3b82f6';
  const logLine = document.createElement('div');
  logLine.style.cssText = `margin-bottom: 0.25rem; color: ${color};`;
  logLine.textContent = `[${timestamp}] ${icon} ${message}`;
  logContainer.appendChild(logLine);
  logContainer.scrollTop = logContainer.scrollHeight;
}

(function(){
  let initialized = false;

  // Estado del módulo
  const state = {
    config: {
      channelId: '',
      campaignTitle: '',
      token: '',
      phoneId: '',
      apiUrl: '',
      templateName: '',
      language: 'es'
    },
    channels: [], // Canales disponibles desde Supabase
    csvData: [],
    currentFile: null,
    sending: false,
    cancelled: false,
    stats: {
      total: 0,
      success: 0,
      failed: 0,
      pending: 0
    },
    logs: []
  };



  function addLog(message, type = 'info'){
    const logContainer = qs('wsp-loading-logs');
    if(!logContainer) return;
    
    const timestamp = new Date().toLocaleTimeString('es-ES');
    const icon = type === 'error' ? '❌' : type === 'success' ? '✅' : type === 'warning' ? '⚠️' : '🔵';
    const color = type === 'error' ? '#dc2626' : type === 'success' ? '#16a34a' : type === 'warning' ? '#ea580c' : '#3b82f6';
    
    const logLine = document.createElement('div');
    logLine.style.cssText = `margin-bottom: 0.25rem; color: ${color};`;
    logLine.textContent = `[${timestamp}] ${icon} ${message}`;
    
    logContainer.appendChild(logLine);
    logContainer.scrollTop = logContainer.scrollHeight;
  }

  function setError(message){
    const errorWrap = qs('wsp-error');
    const errorText = qs('wsp-error-text');
    if(errorWrap && errorText){
      errorText.textContent = message || '';
      errorWrap.classList.toggle('hidden', !message);
    }
  }

  function showPanel(panelId, show = true){
    const panel = qs(panelId);
    if(panel) panel.classList.toggle('hidden', !show);
  }

  function openModal(modalId){
    const modal = qs(modalId);
    if(modal) {
      modal.classList.add('active');
      document.body.style.overflow = 'hidden';
    }
  }

  function closeModal(modalId){
    const modal = qs(modalId);
    if(modal) {
      modal.classList.remove('active');
      document.body.style.overflow = '';
    }
  }

  // Manejadores de eventos para modales
  function setupModalHandlers(){
    // Cerrar modal al hacer clic en overlay o botón cerrar
    document.addEventListener('click', (e) => {
      const closeTarget = e.target.getAttribute('data-close');
      if(closeTarget){
        e.preventDefault();
        closeModal(closeTarget);
        return;
      }

      // Cerrar modal si se hace clic en el overlay
      if(e.target.classList.contains('wsp-modal-overlay')){
        const modal = e.target.closest('.wsp-modal');
        if(modal && modal.classList.contains('active')){
          closeModal(modal.id);
        }
      }
    });

    // Cerrar modal con ESC
    document.addEventListener('keydown', (e) => {
      if(e.key === 'Escape'){
        const activeModal = qs('.wsp-modal.active');
        if(activeModal){
          closeModal(activeModal.id);
        }
      }
    });
  }

  // ==================== CHANNELS LOADING ====================
  async function loadChannels(){
    try {
      console.log('🛰️ loadChannels() iniciado');
      addLog('Iniciando carga de buzones...');
      
      if(!window.App || !window.App.supabase){
        console.error('Supabase client no está disponible');
        addLog('Error: Cliente de base de datos no disponible', 'error');
        setError('Error: Cliente de base de datos no disponible');
        // Forzar visibilidad del panel y selector aunque falle la carga
        showPanel('wsp-config-panel', true);
        const selector = qs('wsp-channel-selector');
        if(selector) selector.disabled = false;
        return;
      }

      addLog('Consultando canales de WhatsApp en Supabase...');
      console.log('🔍 Consultando canales de WhatsApp...');

      // Consultar la tabla instancias.instancias_inputs directamente
        const { data, error } = await window.App.supabase
          .from('whatsapp_channels')
          .select('*')
          .eq('canal', 'WHATSAPP_ENVIO_MASIVO')
          .in('status', ['live', 'test'])
          .order('custom_name', { ascending: true });

      if(error){
        console.error('❌ Error cargando canales:', error);
        addLog(`Error al cargar canales: ${error.message}`, 'error');
        setError('Error al cargar los canales de WhatsApp: ' + error.message);
        // Forzar visibilidad del panel y selector aunque falle la carga
        showPanel('wsp-config-panel', true);
        const selector = qs('wsp-channel-selector');
        if(selector) selector.disabled = false;
        return;
      }

      console.log('📊 Datos recibidos:', data);

      state.channels = data || [];
      
      addLog(`${state.channels.length} canal(es) encontrado(s)`, state.channels.length > 0 ? 'success' : 'warning');
      
      if(state.channels.length > 0){
        // Mostrar detalles de cada canal
        state.channels.forEach(channel => {
          addLog(`  • Buzón: ${channel.custom_name} (${channel.status})`, 'success');
        });
      }
      
      populateChannelSelector();
      console.log(`✅ ${state.channels.length} canales cargados`);
      
      if(state.channels.length === 0){
        console.warn('⚠️ No hay canales de WhatsApp configurados');
        addLog('No hay buzones configurados. Contacta al administrador.', 'warning');
        setError('No hay buzones de WhatsApp configurados. Por favor configura uno en la base de datos.');
        // Forzar visibilidad del panel y selector aunque no haya canales
        showPanel('wsp-config-panel', true);
        const selector = qs('wsp-channel-selector');
        if(selector) selector.disabled = false;
      } else {
        addLog('Buzones cargados correctamente. Puedes seleccionar uno.', 'success');
      }
    } catch(e){
      console.error('❌ Error en loadChannels:', e);
      addLog(`Error crítico: ${e.message}`, 'error');
      setError('Error al cargar los canales: ' + e.message);
    }
  }

  function populateChannelSelector(){
    const selector = qs('wsp-channel-selector');
    if(!selector) {
      console.error('❌ FATAL: No se encontró el elemento ID "wsp-channel-selector" en el HTML.');
      addLog('Error de interfaz: No se encontró el selector de buzones.', 'error');
      return;
    }

    // Limpiar opciones existentes excepto la primera
    selector.innerHTML = '<option value="">Seleccionar buzón...</option>';

    state.channels.forEach(channel => {
      const option = document.createElement('option');
      option.value = channel.nameid;
      option.textContent = channel.custom_name;
      option.dataset.channelData = JSON.stringify(channel);
      selector.appendChild(option);
    });

    // Desocultar panel de configuración y habilitar selector
    showPanel('wsp-config-panel', true);
    selector.disabled = false;
    addLog('Selector de buzón listo para usar', 'success');
  }

  function parseChannelKey(keyString){
    // El formato es: {token},{phone_id},{idWaba}
    if(!keyString) return {};
    const parts = keyString.split(',').map(p => p.trim()).filter(Boolean);
    return {
      token: parts[0] || '',
      phone_id: parts[1] || '',
      idWaba: parts[2] || ''
    };
  }

  // ==================== TEMPLATE MODAL CONFIGURATION ====================
  let lastTemplates = [];

  function getCurrentTemplate() {
    const templateSelector = qs('wsp-template-selector');
    if(!templateSelector || !templateSelector.value) return null;

    const option = templateSelector.options[templateSelector.selectedIndex];
    if(!option || !option.dataset.template) return null;

    try {
      return JSON.parse(option.dataset.template);
    } catch (error) {
      console.error('Error al parsear template:', error);
      return null;
    }
  }

  function extractTemplateVariables(template) {
    const variables = [];
    const components = template.components || [];

    components.forEach(component => {
      if(component.type === 'HEADER' && component.format === 'TEXT' && component.text) {
        const matches = component.text.match(/\{\{(\d+)\}\}/g);
        if(matches) {
          matches.forEach(match => {
            const index = match.replace(/\{|\}/g, '');
            variables.push({
              index,
              name: 'Encabezado',
              type: 'text',
              example: 'Nombre del cliente',
              component: 'header'
            });
          });
        }
      }

      if(component.type === 'BODY' && component.text) {
        const matches = component.text.match(/\{\{(\d+)\}\}/g);
        if(matches) {
          matches.forEach(match => {
            const index = match.replace(/\{|\}/g, '');
            variables.push({
              index,
              name: 'Cuerpo del mensaje',
              type: component.text.length > 100 ? 'textarea' : 'text',
              example: 'Contenido personalizado',
              component: 'body'
            });
          });
        }
      }

      if(component.type === 'FOOTER' && component.text) {
        const matches = component.text.match(/\{\{(\d+)\}\}/g);
        if(matches) {
          matches.forEach(match => {
            const index = match.replace(/\{|\}/g, '');
            variables.push({
              index,
              name: 'Pie de mensaje',
              type: 'text',
              example: 'Información adicional',
              component: 'footer'
            });
          });
        }
      }
    });

    // Eliminar duplicados por índice
    const uniqueVars = variables.filter((v, i, arr) =>
      arr.findIndex(item => item.index === v.index) === i
    );

    return uniqueVars.sort((a, b) => parseInt(a.index) - parseInt(b.index));
  }

  function updateTemplatePreview(template) {
    const headerEl = qs('wsp-modal-header');
    const bodyEl = qs('wsp-modal-body');
    const footerEl = qs('wsp-modal-footer');

    if(!template || !template.components) return;

    // Limpiar contenido anterior
    if(headerEl) headerEl.textContent = '';
    if(bodyEl) bodyEl.textContent = '';
    if(footerEl) footerEl.textContent = '';

    // Obtener valores de variables
    const variableValues = {};
    const varInputs = document.querySelectorAll('[data-var-index]');
    varInputs.forEach(input => {
      const index = input.getAttribute('data-var-index');
      variableValues[index] = input.value || `{{${index}}}`;
    });

    template.components.forEach(component => {
      switch(component.type) {
        case 'HEADER':
          if(headerEl && component.format === 'TEXT') {
            let headerText = component.text || '';
            // Reemplazar variables
            Object.keys(variableValues).forEach(index => {
              const regex = new RegExp(`\\{\\{${index}\\}\\}`, 'g');
              headerText = headerText.replace(regex, variableValues[index]);
            });
            headerEl.textContent = headerText;
          }
          break;

        case 'BODY':
          if(bodyEl) {
            let bodyText = component.text || '';
            // Reemplazar variables
            Object.keys(variableValues).forEach(index => {
              const regex = new RegExp(`\\{\\{${index}\\}\\}`, 'g');
              bodyText = bodyText.replace(regex, variableValues[index]);
            });
            bodyEl.textContent = bodyText;
          }
          break;

        case 'FOOTER':
          if(footerEl) {
            let footerText = component.text || '';
            // Reemplazar variables
            Object.keys(variableValues).forEach(index => {
              const regex = new RegExp(`\\{\\{${index}\\}\\}`, 'g');
              footerText = footerText.replace(regex, variableValues[index]);
            });
            footerEl.textContent = footerText;
          }
          break;
      }
    });
  }

  function generateVariableConfig(template) {
    const varsContainer = qs('wsp-modal-vars');
    if(!varsContainer) return;

    varsContainer.innerHTML = '';

    // Extraer variables del template
    const variables = extractTemplateVariables(template);

    if(variables.length === 0) {
      varsContainer.innerHTML = '<p style="color: var(--text-muted); font-style: italic; text-align: center; padding: 2rem;">Esta plantilla no tiene variables configurables.</p>';
      return;
    }

    variables.forEach((variable, index) => {
      const varGroup = document.createElement('div');
      varGroup.className = 'wsp-modal-var-group';

      const label = document.createElement('label');
      label.textContent = `Variable {{${variable.index}}}: ${variable.name || `Parámetro ${variable.index}`}`;

      const input = document.createElement(variable.type === 'textarea' ? 'textarea' : 'input');
      input.type = variable.type === 'textarea' ? undefined : 'text';
      input.placeholder = variable.example || `Ingresa el valor para {{${variable.index}}}`;
      input.value = variable.default || '';
      input.setAttribute('data-var-index', variable.index);

      if(variable.type === 'textarea') {
        input.rows = 3;
      }

      // Event listener para actualizar preview en tiempo real
      input.addEventListener('input', () => updateTemplatePreview(template));

      varGroup.appendChild(label);
      varGroup.appendChild(input);

      if(variable.description) {
        const desc = document.createElement('div');
        desc.className = 'var-description';
        desc.textContent = variable.description;
        varGroup.appendChild(desc);
      }

      varsContainer.appendChild(varGroup);
    });
  }

  async function showTemplatePreview(){
    const selectedTemplate = getCurrentTemplate();
    if(!selectedTemplate){
      addLog('No hay plantilla seleccionada', 'warning');
      return;
    }

    try {
      addLog(`Mostrando configuración para: ${selectedTemplate.name}`, 'info');

      // Abrir modal
      openModal('wsp-message-config-modal');

      // Actualizar información de la plantilla
      const templateNameEl = qs('wsp-modal-template-name');
      const templateLangEl = qs('wsp-modal-template-lang');
      const templateCategoryEl = qs('wsp-modal-template-category');

      if(templateNameEl) templateNameEl.textContent = selectedTemplate.name;
      if(templateLangEl) templateLangEl.textContent = selectedTemplate.language;
      if(templateCategoryEl) templateCategoryEl.textContent = selectedTemplate.category || 'MARKETING';

      // Generar configuración de variables
      generateVariableConfig(selectedTemplate);

      // Actualizar preview inicial
      updateTemplatePreview(selectedTemplate);

    } catch (error) {
      console.error('Error al mostrar preview:', error);
      addLog(`Error al mostrar configuración: ${error.message}`, 'error');
    }
  }

  function onChannelSelect(event){
    const selectedOption = event.target.options[event.target.selectedIndex];
    if(!selectedOption || !selectedOption.dataset.channelData){
      return;
    }

    try {
      const channelData = JSON.parse(selectedOption.dataset.channelData);

      // Parsear el campo key (SIN mostrar información sensible)
      const keyData = parseChannelKey(channelData.key || '');

      // Auto-rellenar los campos técnicos (ocultos en la interfaz)
      state.config.channelId = channelData.nameid;
      state.config.token = keyData.token || '';
      state.config.phoneId = keyData.phone_id || channelData.meta_id || '';
      state.config.idWaba = keyData.idWaba || '';
      state.config.apiUrl = 'https://smart-whatsapp-api-fibex-production-d80a.up.railway.app/enviar-mensaje';

      // Solo mostrar nombre del buzón en logs
      addLog(`Buzón seleccionado: ${channelData.custom_name}`, 'success');
      setError('');

      if(!state.config.idWaba || !state.config.token){
        addLog('No se puede consultar plantillas: falta idWaba o token', 'error');
        populateTemplateSelector([]);
        return;
      }

      addLog('Consultando plantillas disponibles...', 'info');
      fetchTemplatesForWaba(state.config.idWaba, state.config.token);
      // ==================== CONSULTA DE PLANTILLAS ====================
      async function fetchTemplatesForWaba(idWaba, token){
        if(!idWaba || !token){
          addLog('No se puede consultar plantillas: falta idWaba o token', 'error');
          return;
        }
        try {
          addLog('Consultando plantillas de WhatsApp...');
          const url = `https://graph.facebook.com/v21.0/${idWaba}/message_templates?fields=name,status,language,components,category&limit=100`;
          const resp = await fetch(url, {
            headers: { Authorization: `Bearer ${token}` }
          });
          addLog(`Status HTTP: ${resp.status}`, resp.ok ? 'info' : 'error');
          if(!resp.ok){
            addLog('No se pudo conectar con la API de Meta. Revisa el token y permisos.', 'error');
            console.error('Error HTTP Meta:', await resp.text());
            populateTemplateSelector([]);
            return;
          }
          const json = await resp.json();
          if(json.data && Array.isArray(json.data) && json.data.length > 0){
            populateTemplateSelector(json.data);
            addLog(`Plantillas recibidas: ${json.data.length}`, 'success');
          } else {
            addLog('No se recibieron plantillas o el formato es incorrecto', 'warning');
            populateTemplateSelector([]);
          }
        } catch(e){
          addLog('Error consultando plantillas: ' + e.message, 'error');
          console.error('Error fetchTemplatesForWaba:', e);
          populateTemplateSelector([]);
        }
      }

      function populateTemplateSelector(templates){
        lastTemplates = templates;
        const selector = qs('wsp-template-selector');
        if(!selector) return;
        selector.innerHTML = '<option value="">Seleccionar plantilla...</option>';
        templates.forEach(t => {
          const opt = document.createElement('option');
          opt.value = t.name;
          opt.textContent = `${t.name} (${t.language}) [${t.category}]`;
          opt.dataset.template = JSON.stringify(t);
          selector.appendChild(opt);
        });
        // Eliminar listeners previos para evitar duplicados
        selector.onchange = null;
        selector.addEventListener('change', e => {
          if(e.target.value) {
            // Cambiar a showTemplatePreview sin parámetros
            showTemplatePreview();
          }
        });
      }
    } catch(e){
      console.error('Error parseando datos del canal:', e);
      setError('Error al cargar la configuración del buzón');
    }
  }

  // ==================== CONFIG ====================
  function saveConfig(){
    state.config.channelId = qs('wsp-channel-selector')?.value || '';
    state.config.campaignTitle = qs('wsp-campaign-title')?.value.trim() || '';
    state.config.templateName = qs('wsp-template-name')?.value.trim() || 'servicio_suspendido'; // Template fijo
    state.config.language = qs('wsp-language')?.value || 'es';

    if(!state.config.channelId){
      setError('Por favor selecciona un buzón de envío');
      addLog('Error: Debes seleccionar un buzón', 'error');
      return false;
    }

    if(!state.config.campaignTitle){
      setError('Por favor ingresa un título para la campaña');
      addLog('Error: Debes ingresar un título', 'error');
      return false;
    }

    // Guardar en localStorage
    localStorage.setItem('wsp_config', JSON.stringify(state.config));
    setError('');
    addLog('Configuración guardada correctamente', 'success');
    alert('✅ Configuración guardada correctamente');
    return true;
  }

  function loadConfig(){
    try {
      const saved = localStorage.getItem('wsp_config');
      if(saved){
        const config = JSON.parse(saved);
        state.config = config;
        
        if(qs('wsp-channel-selector')) qs('wsp-channel-selector').value = config.channelId || '';
        if(qs('wsp-campaign-title')) qs('wsp-campaign-title').value = config.campaignTitle || '';
        if(qs('wsp-template-selector')) qs('wsp-template-selector').value = config.templateName || '';
        if(qs('wsp-language')) qs('wsp-language').value = config.language || 'es';
      }
    } catch(e){
      console.error('Error cargando config:', e);
    }
  }

  // ==================== FILE HANDLING ====================
  function handleFileSelect(file){
    if(!file || !file.name.endsWith('.csv')){
      setError('Por favor selecciona un archivo CSV válido');
      return;
    }

    state.currentFile = file;
    
    // Mostrar info del archivo
    if(qs('wsp-file-name')) qs('wsp-file-name').textContent = file.name;
    if(qs('wsp-file-size')) qs('wsp-file-size').textContent = formatBytes(file.size);
    showPanel('wsp-file-info', true);

    // Leer y parsear CSV
    const reader = new FileReader();
    reader.onload = (e) => parseCSV(e.target.result);
    reader.onerror = () => setError('Error leyendo el archivo');
    reader.readAsText(file);
  }

  function parseCSV(text){
    try {
      const lines = text.split('\n').filter(line => line.trim());
      if(lines.length < 2){
        setError('El CSV debe tener al menos una fila de encabezados y una de datos');
        return;
      }

      const headers = lines[0].split(',').map(h => h.trim());
      const data = [];

      for(let i = 1; i < lines.length; i++){
        const values = lines[i].split(',').map(v => v.trim());
        const row = {};
        headers.forEach((header, idx) => {
          row[header] = values[idx] || '';
        });
        
        // Validar que tenga al menos número
        if(row.numero){
          data.push(row);
        }
      }

      if(data.length === 0){
        setError('No se encontraron filas válidas con números de teléfono');
        return;
      }

      state.csvData = data;
      renderPreview(headers, data);
      setError('');
    } catch(e){
      console.error('Error parseando CSV:', e);
      setError('Error al procesar el archivo CSV');
    }
  }

  function renderPreview(headers, data){
    const previewTable = qs('wsp-preview-table');
    if(!previewTable) return;

    const preview = data.slice(0, 5);
    let html = '<table><thead><tr>';
    headers.forEach(h => html += `<th>${h}</th>`);
    html += '</tr></thead><tbody>';
    
    preview.forEach(row => {
      html += '<tr>';
      headers.forEach(h => html += `<td>${row[h] || '-'}</td>`);
      html += '</tr>';
    });
    html += '</tbody></table>';
    
    previewTable.innerHTML = html;
    
    if(qs('wsp-total-rows')){
      qs('wsp-total-rows').textContent = `Total de registros: ${data.length}`;
    }
    
    showPanel('wsp-preview', true);
  }

  function clearFile(){
    state.currentFile = null;
    state.csvData = [];
    showPanel('wsp-file-info', false);
    showPanel('wsp-preview', false);
    if(qs('wsp-file-input')) qs('wsp-file-input').value = '';
  }

  // ==================== SENDING ====================
  async function startSending(){
    // Validar que se hayan configurado los datos necesarios
    if(!state.config.channelId || !state.config.token || !state.config.phoneId){
      setError('Por favor selecciona un buzón de envío primero');
      return;
    }

    if(!state.config.templateName){
      setError('Por favor ingresa el nombre de la plantilla');
      return;
    }

    if(state.csvData.length === 0){
      setError('Por favor carga un archivo CSV con destinatarios');
      return;
    }

    state.sending = true;
    state.cancelled = false;
    state.stats = {
      total: state.csvData.length,
      success: 0,
      failed: 0,
      pending: state.csvData.length
    };
    state.logs = [];

    // Mostrar panel de progreso
    showPanel('wsp-progress-panel', true);
    updateStats();
    clearLog();

    // Deshabilitar botón de inicio
    const startBtn = qs('wsp-start-send');
    if(startBtn) startBtn.disabled = true;

    // Procesar cada fila
    for(let i = 0; i < state.csvData.length; i++){
      if(state.cancelled){
        addLog('⚠️', 'Envío cancelado por el usuario', 'warning');
        break;
      }

      const row = state.csvData[i];
      await sendMessage(row, i + 1);
      
      // Delay de 2 segundos entre mensajes
      if(i < state.csvData.length - 1 && !state.cancelled){
        await sleep(2000);
      }
    }

    state.sending = false;
    if(startBtn) startBtn.disabled = false;
    
    if(!state.cancelled){
      addLog('✅', 'Envío completado', 'success');
    }
  }

  async function sendMessage(row, index){
    const { numero, variable1, variable2, variable3, variable4 } = row;
    
    if(!numero){
      state.stats.failed++;
      state.stats.pending--;
      updateStats();
      addLog('❌', `Fila ${index}: Sin número de teléfono`, 'error');
      return;
    }

    // Preparar variables (filtrar vacíos)
    const variables = [variable1, variable2, variable3, variable4].filter(v => v);

    // Preparar body de la request (formato exacto que espera la API)
    const body = {
      token: state.config.token,
      phone_id: state.config.phoneId,
      numero: numero,
      template_name: state.config.templateName
    };

    // Solo agregar variables si existen
    if(variables.length > 0) body.variables = variables;

    // Debug: mostrar body en consola
    console.log('📤 Enviando request:', JSON.stringify(body, null, 2));

    try {
      // 🔧 Llamada directa a la API (sin proxy CORS)
      const response = await fetch(state.config.apiUrl, {
        method: 'POST',
        mode: 'cors',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(body)
      });

      const result = await response.json();

      if(response.ok && result.status === 'success'){
        state.stats.success++;
        state.stats.pending--;
        updateStats();
        addLog('✅', `${numero} - Enviado correctamente (ID: ${result.id || 'N/A'})`, 'success');
      } else {
        throw new Error(result.meta_error || result.message || 'Error desconocido');
      }
    } catch(error){
      state.stats.failed++;
      state.stats.pending--;
      updateStats();
      addLog('❌', `${numero} - Error: ${error.message}`, 'error');
    }
  }

  function updateStats(){
    if(qs('wsp-stat-total')) qs('wsp-stat-total').textContent = state.stats.total;
    if(qs('wsp-stat-success')) qs('wsp-stat-success').textContent = state.stats.success;
    if(qs('wsp-stat-failed')) qs('wsp-stat-failed').textContent = state.stats.failed;
    if(qs('wsp-stat-pending')) qs('wsp-stat-pending').textContent = state.stats.pending;

    const progress = state.stats.total > 0 
      ? ((state.stats.success + state.stats.failed) / state.stats.total) * 100 
      : 0;
    
    const progressBar = qs('wsp-progress-bar');
    if(progressBar){
      progressBar.style.width = `${progress}%`;
      progressBar.textContent = `${Math.round(progress)}%`;
    }
  }

  function addLog(icon, message, type = 'info'){
    const timestamp = new Date().toLocaleTimeString('es-CO');
    state.logs.push({ icon, message, type, timestamp });

    const logContainer = qs('wsp-log');
    if(!logContainer) return;

    const entry = document.createElement('div');
    entry.className = 'wsp-log-entry';
    entry.innerHTML = `
      <div class="wsp-log-icon">${icon}</div>
      <div class="wsp-log-content">
        <div class="wsp-log-number">${message}</div>
        <div class="wsp-log-time">${timestamp}</div>
      </div>
    `;
    
    logContainer.insertBefore(entry, logContainer.firstChild);
    
    // Scroll al top para ver el último mensaje
    logContainer.scrollTop = 0;
  }

  function clearLog(){
    const logContainer = qs('wsp-log');
    if(logContainer) logContainer.innerHTML = '';
  }

  function cancelSending(){
    if(confirm('¿Estás seguro de cancelar el envío en curso?')){
      state.cancelled = true;
      state.sending = false;
    }
  }

  function resetCampaign(){
    if(state.sending){
      alert('No puedes resetear mientras hay un envío en curso');
      return;
    }

    if(confirm('¿Iniciar una nueva campaña? Esto limpiará todos los datos actuales.')){
      clearFile();
      state.stats = { total: 0, success: 0, failed: 0, pending: 0 };
      state.logs = [];
      updateStats();
      clearLog();
      showPanel('wsp-progress-panel', false);
      setError('');
    }
  }

  function exportLog(){
    if(state.logs.length === 0){
      alert('No hay registros para exportar');
      return;
    }

    let csv = 'Hora,Icono,Mensaje\n';
    state.logs.forEach(log => {
      csv += `${log.timestamp},"${log.icon}","${log.message}"\n`;
    });

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `whatsapp_log_${new Date().getTime()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  // ==================== HELPERS ====================
  function sleep(ms){ return new Promise(r => setTimeout(r, ms)); }

  function formatBytes(bytes){
    if(bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
  }

  // ==================== DOWNLOAD TEMPLATE ====================
  function downloadTemplate(){
    const csvContent = `numero,variable1,variable2,variable3,variable4,url_imagen
584121234567,Juan,25.00,Promoción,Mes de Enero,https://ejemplo.com/promo.jpg
584129876543,María,30.00,Descuento,Mes de Febrero,
584125555555,Pedro,15.50,Oferta,Mes de Marzo,https://ejemplo.com/oferta.png`;
    
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'template_whatsapp.csv';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  // ==================== EVENT LISTENERS ====================
  function attachEvents(){
    console.log('🔍 Buscando elementos del DOM...');
    
    // Channel selector
    const channelSelector = qs('wsp-channel-selector');
    if(channelSelector){
      console.log('✓ Selector de canal encontrado');
      channelSelector.addEventListener('change', onChannelSelect);
    } else {
      console.warn('✗ Selector de canal NO encontrado');
    }

    // Config - Prevenir submit del form
    const configForm = qs('wsp-config-form');
    if(configForm){
      console.log('✓ Form de config encontrado');
      configForm.addEventListener('submit', (e) => {
        e.preventDefault();
        console.log('📝 Submit del form interceptado');
        saveConfig();
      });
    } else {
      console.warn('✗ Form de config NO encontrado');
    }

    const saveConfigBtn = qs('wsp-save-config');
    if(saveConfigBtn){
      console.log('✓ Botón guardar config encontrado');
      saveConfigBtn.addEventListener('click', (e) => {
        e.preventDefault();
        console.log('💾 Click en guardar configuración');
        saveConfig();
      });
    } else {
      console.warn('✗ Botón guardar config NO encontrado');
    }

    // Download template
    const downloadTemplateBtn = qs('wsp-download-template');
    if(downloadTemplateBtn){
      console.log('✓ Botón descargar template encontrado');
      downloadTemplateBtn.addEventListener('click', (e) => {
        e.preventDefault();
        console.log('📥 Click en descargar template');
        downloadTemplate();
      });
    } else {
      console.warn('✗ Botón descargar template NO encontrado');
    }

    // File upload
    const selectFileBtn = qs('wsp-select-file');
    const fileInput = qs('wsp-file-input');
    const dropZone = qs('wsp-drop-zone');

    if(selectFileBtn && fileInput){
      console.log('✓ Botón seleccionar archivo encontrado');
      selectFileBtn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        console.log('📂 Click en seleccionar archivo');
        fileInput.click();
      });
      fileInput.addEventListener('change', (e) => {
        console.log('📄 Archivo seleccionado');
        if(e.target.files.length > 0) handleFileSelect(e.target.files[0]);
      });
    } else {
      console.warn('✗ Botón o input de archivo NO encontrados');
    }

    if(dropZone){
      console.log('✓ Zona de drop encontrada');
      dropZone.addEventListener('click', (e) => {
        // Solo abrir el file input si se hace clic en el dropZone pero no en el botón
        if(e.target.id === 'wsp-select-file' || e.target.closest('#wsp-select-file')){
          return; // El botón ya tiene su propio handler
        }
        console.log('📂 Click en zona de drop');
        fileInput?.click();
      });
      
      dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        dropZone.classList.add('dragover');
      });
      
      dropZone.addEventListener('dragleave', () => {
        dropZone.classList.remove('dragover');
      });
      
      dropZone.addEventListener('drop', (e) => {
        e.preventDefault();
        dropZone.classList.remove('dragover');
        console.log('📄 Archivo dropeado');
        if(e.dataTransfer.files.length > 0){
          handleFileSelect(e.dataTransfer.files[0]);
        }
      });
    } else {
      console.warn('✗ Zona de drop NO encontrada');
    }

    const clearFileBtn = qs('wsp-clear-file');
    if(clearFileBtn){
      console.log('✓ Botón limpiar archivo encontrado');
      clearFileBtn.addEventListener('click', () => clearFile());
    } else {
      console.warn('✗ Botón limpiar archivo NO encontrado');
    }

    // Sending
    const startSendBtn = qs('wsp-start-send');
    if(startSendBtn){
      console.log('✓ Botón iniciar envío encontrado');
      startSendBtn.addEventListener('click', () => startSending());
    } else {
      console.warn('✗ Botón iniciar envío NO encontrado');
    }

    const cancelBtn = qs('wsp-cancel-send');
    if(cancelBtn){
      console.log('✓ Botón cancelar encontrado');
      cancelBtn.addEventListener('click', () => cancelSending());
    } else {
      console.warn('✗ Botón cancelar NO encontrado');
    }

    const resetBtn = qs('wsp-reset');
    if(resetBtn){
      console.log('✓ Botón reset encontrado');
      resetBtn.addEventListener('click', () => resetCampaign());
    } else {
      console.warn('✗ Botón reset NO encontrado');
    }

    const exportLogBtn = qs('wsp-export-log');
    if(exportLogBtn){
      console.log('✓ Botón exportar log encontrado');
      exportLogBtn.addEventListener('click', () => exportLog());
    } else {
      console.warn('✗ Botón exportar log NO encontrado');
    }

    // Help modal
    const helpBtn = qs('wsp-help');
    if(helpBtn){
      console.log('✓ Botón ayuda encontrado');
      helpBtn.addEventListener('click', () => openModal('wsp-help-modal'));
    } else {
      console.warn('✗ Botón ayuda NO encontrado');
    }

    // Modal close handlers
    const closeButtons = document.querySelectorAll('[data-close]');
    console.log(`✓ ${closeButtons.length} botones de cerrar modal encontrados`);
    closeButtons.forEach(btn => {
      btn.addEventListener('click', (e) => {
        const modalId = e.target.getAttribute('data-close') || e.target.closest('[data-close]')?.getAttribute('data-close');
        if(modalId) closeModal(modalId);
      });
    });
    
    console.log('✅ Todos los event listeners adjuntados');
  }

  // ==================== LIFECYCLE ====================
  function init(){
    if(initialized) return;
    
    console.log('🚀 Iniciando módulo WhatsApp...');
    
    // Función de inicialización que se ejecuta cuando el DOM está listo
    const doInit = async () => {
      if(initialized) return;
      
      console.log('🧭 doInit disparado (WhatsApp)');
      addLog('Iniciando inicialización de WhatsApp...', 'info');

      // Verificar que el DOM objetivo existe antes de continuar
      const selectorExists = qs('wsp-channel-selector');
      if(!selectorExists){
        console.warn('⚠️ DOM no listo para WhatsApp. Reintentando en 100ms...');
        addLog('DOM no listo, reintentando...', 'warning');
        setTimeout(doInit, 100);
        return;
      }

      initialized = true;

      try {
        console.log('🚚 Entrando a loadChannels()');
        addLog('Solicitando buzones a Supabase...', 'info');
        console.log('📡 Cargando canales desde Supabase...');
        await loadChannels();
        console.log('✅ Canales cargados, continuando...');
        
        console.log('📋 Cargando configuración...');
        loadConfig();
        
        console.log('🔗 Adjuntando event listeners...');
        attachEvents();
        
        // Configurar handlers de modales
        setupModalHandlers();
        
        // Event listener para el botón "Aplicar Configuración"
        const applyConfigBtn = qs('wsp-apply-config');
        if(applyConfigBtn){
          applyConfigBtn.addEventListener('click', () => {
            addLog('✅', 'Configuración aplicada correctamente', 'success');
            closeModal('wsp-message-config-modal');
          });
        }

        // Event listener para el botón de vista previa de plantilla
        const previewBtn = qs('wsp-preview-template');
        if(previewBtn){
          previewBtn.addEventListener('click', () => {
            showTemplatePreview();
          });
        }

        // Habilitar botón de vista previa cuando se seleccione una plantilla
        const templateSelector = qs('wsp-template-selector');
        if(templateSelector){
          templateSelector.addEventListener('change', () => {
            if(previewBtn){
              previewBtn.disabled = !templateSelector.value;
            }
          });
        }

        showPanel('wsp-progress-panel', false);
        
        console.log('✅ Módulo WhatsApp inicializado correctamente');
      } catch(error) {
        console.error('❌ Error en inicialización:', error);
      }
    };
    
    // Si el DOM ya está listo, inicializar inmediatamente
    if(document.readyState === 'loading'){
      document.addEventListener('DOMContentLoaded', doInit);
    } else {
      // DOM ya está listo, usar un pequeño delay para asegurar que todo esté montado
      setTimeout(doInit, 50);
    }
  }

  function destroy(){
    initialized = false;
    // Cancelar envío si está en curso
    if(state.sending){
      state.cancelled = true;
      state.sending = false;
    }
    console.log('🗑️ Módulo WhatsApp destruido');
  }

  // Exportar funciones públicas
  window.WhatsAppModule = { init, destroy };
})();

// NO auto-init aquí, el router lo llamará cuando cargue la vista

