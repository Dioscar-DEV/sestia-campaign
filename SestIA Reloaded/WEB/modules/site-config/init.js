(function(){
  
  const PRESETS = {
    light: {
      bg: '#ffffff', panel: '#ffffff', panel2: '#f8fafc', text: '#0f172a', muted: '#64748b', border: '#e2e8f0',
      brand: '#3b82f6', brandLight: '#60a5fa', accent: '#1e40af',
      success: '#10b981', warning: '#f59e0b', danger: '#dc2626', info: '#0ea5e9'
    },
    dark: {
      bg: '#0f172a', panel: '#1e293b', panel2: '#334155', text: '#f8fafc', muted: '#94a3b8', border: '#334155',
      brand: '#3b82f6', brandLight: '#60a5fa', accent: '#60a5fa',
      success: '#34d399', warning: '#fbbf24', danger: '#f87171', info: '#38bdf8'
    },
    ocean: {
      bg: '#f0f9ff', panel: '#ffffff', panel2: '#e0f2fe', text: '#0c4a6e', muted: '#64748b', border: '#bae6fd',
      brand: '#0284c7', brandLight: '#38bdf8', accent: '#0369a1',
      success: '#10b981', warning: '#f59e0b', danger: '#ef4444', info: '#0ea5e9'
    },
    forest: {
      bg: '#f0fdf4', panel: '#ffffff', panel2: '#dcfce7', text: '#14532d', muted: '#64748b', border: '#bbf7d0',
      brand: '#16a34a', brandLight: '#4ade80', accent: '#15803d',
      success: '#16a34a', warning: '#eab308', danger: '#dc2626', info: '#0ea5e9'
    },
    sunset: {
      bg: '#fff7ed', panel: '#ffffff', panel2: '#ffedd5', text: '#7c2d12', muted: '#9a3412', border: '#fed7aa',
      brand: '#ea580c', brandLight: '#fb923c', accent: '#c2410c',
      success: '#10b981', warning: '#f59e0b', danger: '#ef4444', info: '#0ea5e9'
    }
  };

  class SiteConfigModule {
    constructor() {
      this.supabase = window.App.supabase;
      this.state = {
        config: {
          site: {},
          theme: {}
        },
        loading: false,
        currentBaseTheme: { // Valores por defecto (Light)
          bg: '#ffffff', panel: '#ffffff', panel2: '#f8fafc', text: '#0f172a', muted: '#64748b', border: '#e2e8f0'
        }
      };
    }

    async init() {
      console.log('⚙️ Inicializando módulo de configuración...');
      // Asegurar acceso a Supabase
      if (!this.supabase && window.App?.supabase) {
        this.supabase = window.App.supabase;
      }
      
      this.bindEvents();
      await this.loadConfig();
    }

    bindEvents() {
      // Tabs
      const tabs = document.querySelectorAll('#site-config-module .tab-btn');
      tabs.forEach(tab => {
        tab.addEventListener('click', (e) => {
          const target = e.currentTarget.dataset.tab;
          this.switchTab(target);
        });
      });

      // Botones de acción
      document.getElementById('config-refresh')?.addEventListener('click', () => this.loadConfig());
      document.getElementById('config-save')?.addEventListener('click', () => this.saveConfig());
      
      // Presets
      document.querySelectorAll('.preset-card').forEach(btn => {
        btn.addEventListener('click', (e) => {
          const preset = e.currentTarget.dataset.preset;
          this.applyPreset(preset);
        });
      });

      // Sincronización de color pickers con inputs de texto y LIVE PREVIEW
      const colorInputs = document.querySelectorAll('input[type="color"]');
      colorInputs.forEach(input => {
        const textInput = document.getElementById(input.id.replace('color-', 'text-'));
        
        // Color -> Texto & Preview
        input.addEventListener('input', (e) => {
          if(textInput) textInput.value = e.target.value;
          this.updatePreview();
        });

        // Texto -> Color & Preview
        if(textInput) {
          textInput.addEventListener('input', (e) => {
            if(/^#[0-9A-F]{6}$/i.test(e.target.value)) {
              input.value = e.target.value;
              this.updatePreview();
            }
          });
        }
      });

      // Previsualización de imágenes (Inputs manuales)
      const imgInputs = ['asset-logo', 'asset-banner'];
      imgInputs.forEach(id => {
        const input = document.getElementById(id);
        const previewId = id.replace('asset-', 'preview-');
        const preview = document.getElementById(previewId);
        
        if(input && preview) {
          input.addEventListener('input', (e) => {
            preview.src = e.target.value;
          });
        }
      });

      // Uploaders
      this.bindUploader('upload-logo', 'logos', 'asset-logo');
      this.bindUploader('upload-banner', 'banners', 'asset-banner');

      // Gallery Buttons
      document.getElementById('btn-gallery-logo')?.addEventListener('click', () => this.openGallery('logos', 'asset-logo'));
      document.getElementById('btn-gallery-banner')?.addEventListener('click', () => this.openGallery('banners', 'asset-banner'));
    }

    bindUploader(inputId, folder, targetInputId) {
      const input = document.getElementById(inputId);
      if(!input) return;

      input.addEventListener('change', async (e) => {
        const file = e.target.files[0];
        if(!file) return;

        try {
          const btnLabel = input.parentElement;
          const originalText = btnLabel.innerHTML;
          btnLabel.innerHTML = '...';
          btnLabel.style.pointerEvents = 'none';

          const url = await this.uploadImage(file, folder);
          
          // Actualizar input y disparar evento para preview
          const targetInput = document.getElementById(targetInputId);
          if(targetInput) {
            targetInput.value = url;
            targetInput.dispatchEvent(new Event('input'));
          }

          btnLabel.innerHTML = originalText;
          btnLabel.style.pointerEvents = 'auto';
          
          // Reset input file
          input.value = '';

        } catch (err) {
          console.error('Upload error:', err);
          alert('Error al subir imagen: ' + err.message);
          input.parentElement.innerHTML = input.parentElement.innerHTML; // Reset text
          input.parentElement.style.pointerEvents = 'auto';
        }
      });
    }

    async uploadImage(file, folder) {
      if (!this.supabase) throw new Error('Supabase no inicializado');

      const fileExt = file.name.split('.').pop();
      const fileName = `${Date.now()}-${Math.random().toString(36).substring(2)}.${fileExt}`;
      const filePath = `${folder}/${fileName}`;

      const { error: uploadError } = await this.supabase.storage
        .from('public-assets')
        .upload(filePath, file);

      if (uploadError) throw uploadError;

      const { data } = this.supabase.storage
        .from('public-assets')
        .getPublicUrl(filePath);

      return data.publicUrl;
    }

    async openGallery(folder, targetInputId) {
      const modal = document.getElementById('gallery-modal');
      const grid = document.getElementById('gallery-grid');
      const title = document.getElementById('gallery-title');
      
      if(!modal || !grid) return;

      title.textContent = folder === 'logos' ? 'Galería de Logos' : 'Galería de Banners';
      grid.innerHTML = '<div class="gallery-loading">Cargando imágenes...</div>';
      modal.classList.add('active');

      try {
        const { data, error } = await this.supabase.storage
          .from('public-assets')
          .list(folder, {
            limit: 100,
            offset: 0,
            sortBy: { column: 'created_at', order: 'desc' },
          });

        if (error) throw error;

        grid.innerHTML = '';
        
        if (!data || data.length === 0) {
          grid.innerHTML = '<div class="gallery-loading">No hay imágenes guardadas.</div>';
          return;
        }

        data.forEach(file => {
          if(file.name === '.emptyFolderPlaceholder') return;

          const { data: publicUrlData } = this.supabase.storage
            .from('public-assets')
            .getPublicUrl(`${folder}/${file.name}`);
            
          const url = publicUrlData.publicUrl;

          const item = document.createElement('div');
          item.className = 'gallery-item';
          item.innerHTML = `
            <img src="${url}" loading="lazy" />
            <div class="gallery-actions">
              <button class="btn-delete-img" title="Eliminar">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
              </button>
            </div>
          `;

          // Seleccionar imagen
          item.addEventListener('click', (e) => {
            if(e.target.closest('.btn-delete-img')) return;
            
            const targetInput = document.getElementById(targetInputId);
            if(targetInput) {
              targetInput.value = url;
              targetInput.dispatchEvent(new Event('input'));
            }
            modal.classList.remove('active');
          });

          // Eliminar imagen
          const deleteBtn = item.querySelector('.btn-delete-img');
          deleteBtn.addEventListener('click', async (e) => {
            e.stopPropagation();
            if(!confirm('¿Eliminar esta imagen permanentemente?')) return;

            try {
              const { error: delError } = await this.supabase.storage
                .from('public-assets')
                .remove([`${folder}/${file.name}`]);
              
              if(delError) throw delError;
              
              item.remove();
              if(grid.children.length === 0) {
                grid.innerHTML = '<div class="gallery-loading">No hay imágenes guardadas.</div>';
              }
            } catch(err) {
              alert('Error al eliminar: ' + err.message);
            }
          });

          grid.appendChild(item);
        });

      } catch (err) {
        console.error('Gallery error:', err);
        grid.innerHTML = `<div class="gallery-loading" style="color:var(--danger)">Error: ${err.message}</div>`;
      }
    }

    updatePreview() {
      const container = document.getElementById('theme-preview-container');
      if(!container) return;

      const vars = {
        // Colores editables
        '--brand': this.getVal('text-brand'),
        '--brand-light': this.getVal('text-brand-light'),
        '--accent': this.getVal('text-accent'),
        '--success': this.getVal('text-success'),
        '--warning': this.getVal('text-warning'),
        '--danger': this.getVal('text-danger'),
        '--info': this.getVal('text-info'),
        
        // Colores base del tema (bg, panel, text, etc.)
        '--bg': this.state.currentBaseTheme.bg,
        '--panel': this.state.currentBaseTheme.panel,
        '--panel-2': this.state.currentBaseTheme.panel2,
        '--text': this.state.currentBaseTheme.text,
        '--muted': this.state.currentBaseTheme.muted,
        '--border': this.state.currentBaseTheme.border
      };

      Object.entries(vars).forEach(([key, val]) => {
        if(val) container.style.setProperty(key, val);
      });
    }

    applyPreset(presetName) {
      const preset = PRESETS[presetName];
      if(!preset) return;

      // Actualizar estado base del tema
      this.state.currentBaseTheme = {
        bg: preset.bg,
        panel: preset.panel,
        panel2: preset.panel2,
        text: preset.text,
        muted: preset.muted,
        border: preset.border
      };

      // Aplicar colores a los inputs
      this.setColor('brand', preset.brand);
      this.setColor('brand-light', preset.brandLight);
      this.setColor('accent', preset.accent);
      this.setColor('success', preset.success);
      this.setColor('warning', preset.warning);
      this.setColor('danger', preset.danger);
      this.setColor('info', preset.info);
      
      // Actualizar vista previa inmediatamente
      this.updatePreview();
    }



    openPreview() {
      // Deprecated: Preview is now live
    }

    switchTab(tabName) {
      // Actualizar botones
      document.querySelectorAll('#site-config-module .tab-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tabName);
      });

      // Actualizar paneles
      document.querySelectorAll('#site-config-module .tab-panel').forEach(panel => {
        panel.classList.toggle('active', panel.id === `tab-${tabName}`);
      });
    }

    setLoading(isLoading) {
      this.state.loading = isLoading;
      const loadingEl = document.getElementById('config-loading');
      const contentEl = document.getElementById('config-content');
      
      if(loadingEl) loadingEl.classList.toggle('hidden', !isLoading);
      if(contentEl) contentEl.classList.toggle('hidden', isLoading);
    }

    async loadConfig() {
      this.setLoading(true);
      try {
        // Verificar Supabase antes de llamar
        if (!this.supabase) {
          throw new Error('Cliente Supabase no inicializado');
        }

        const { data, error } = await this.supabase
          .from('frontconfig')
          .select('key, value')
          .in('key', ['site', 'theme']);

        if (error) throw error;

        // Procesar datos
        data.forEach(item => {
          this.state.config[item.key] = item.value;
        });

        this.populateForm();
        this.updatePreview(); // Inicializar preview con datos cargados
        console.log('✅ Configuración cargada:', this.state.config);

      } catch (err) {
        console.error('❌ Error cargando configuración:', err);
        // Mostrar error en UI si es posible, o alert
        const loadingEl = document.getElementById('config-loading');
        if(loadingEl) loadingEl.innerHTML = `<p style="color:var(--danger)">Error: ${err.message}</p>`;
      } finally {
        this.setLoading(false);
      }
    }

    populateForm() {
      const { site, theme } = this.state.config;

      // --- Pestaña General (Site) ---
      if (site) {
        this.setVal('site-title', site.title);
        this.setVal('site-desc', site.description);
        this.setVal('site-author', site.author);
        this.setVal('site-contact', site.contact);
      }

      // --- Pestaña Tema (Theme) ---
      if (theme) {
        // Footer
        if (theme.footer) {
          this.setVal('footer-text', theme.footer.text);
        }

        // Assets
        this.setVal('asset-logo', theme.logoUrl);
        this.setVal('asset-banner', theme.bannerUrl);
        this.setVal('input-brand-name', theme.brandName);
        this.setVal('input-brand-short', theme.brandShort);
        this.setVal('banner-text', theme.bannerText);

        // Actualizar previsualizaciones
        const logoPreview = document.getElementById('preview-logo');
        if(logoPreview) logoPreview.src = theme.logoUrl || '';
        
        const bannerPreview = document.getElementById('preview-banner');
        if(bannerPreview) bannerPreview.src = theme.bannerUrl || '';

        // Colores
        if (theme.colors) {
          // Cargar colores de marca en inputs
          this.setColor('brand', theme.colors.brand);
          this.setColor('brand-light', theme.colors.brandLight);
          this.setColor('accent', theme.colors.accent);
          this.setColor('success', theme.colors.success);
          this.setColor('warning', theme.colors.warning);
          this.setColor('danger', theme.colors.danger);
          this.setColor('info', theme.colors.info);

          // Cargar colores base en el estado local para que el preview funcione al inicio
          this.state.currentBaseTheme = {
            bg: theme.colors.bg || '#ffffff',
            panel: theme.colors.panel || '#ffffff',
            panel2: theme.colors.panel2 || '#f8fafc',
            text: theme.colors.text || '#0f172a',
            muted: theme.colors.muted || '#64748b',
            border: theme.colors.border || '#e2e8f0'
          };
        }
      }
    }

    setVal(id, val) {
      const el = document.getElementById(id);
      if (el) el.value = val || '';
    }

    setColor(name, val) {
      if (!val) return;
      const colorInput = document.getElementById(`color-${name}`);
      const textInput = document.getElementById(`text-${name}`);
      
      if (colorInput) colorInput.value = val;
      if (textInput) textInput.value = val;
    }

    async saveConfig() {
      const btn = document.getElementById('config-save');
      const originalText = btn.innerHTML;
      btn.innerHTML = 'Guardando...';
      btn.disabled = true;

      try {
        // Construir objetos actualizados
        const newSite = {
          ...this.state.config.site,
          title: this.getVal('site-title'),
          description: this.getVal('site-desc'),
          author: this.getVal('site-author'),
          contact: this.getVal('site-contact')
        };

        // Combinar colores base (bg, text, etc.) con colores de marca (inputs)
        const mergedColors = {
          ...this.state.config.theme.colors, // Mantener anteriores por si acaso
          ...this.state.currentBaseTheme,    // Sobrescribir con el tema base actual (bg, panel, text...)
          brand: this.getVal('text-brand'),  // Sobrescribir con inputs actuales
          brandLight: this.getVal('text-brand-light'),
          accent: this.getVal('text-accent'),
          success: this.getVal('text-success'),
          warning: this.getVal('text-warning'),
          danger: this.getVal('text-danger'),
          info: this.getVal('text-info')
        };

        const newTheme = {
          ...this.state.config.theme,
          brandName: this.getVal('input-brand-name'),
          brandShort: this.getVal('input-brand-short'),
          logoUrl: this.getVal('asset-logo'),
          bannerUrl: this.getVal('asset-banner'),
          bannerText: this.getVal('banner-text'),
          footer: {
            ...this.state.config.theme.footer,
            text: this.getVal('footer-text')
          },
          colors: mergedColors
        };

        // Guardar en Supabase (Upsert)
        const updates = [
          { key: 'site', value: newSite, description: 'Configuración general del sitio' },
          { key: 'theme', value: newTheme, description: 'Configuración visual del tema' }
        ];

        const { error } = await this.supabase
          .from('frontconfig')
          .upsert(updates, { onConflict: 'key' });

        if (error) throw error;

        // Actualizar estado local
        this.state.config.site = newSite;
        this.state.config.theme = newTheme;

        alert('✅ Configuración guardada correctamente.');
        
        // Recargar tema en caliente
        if (window.reloadTheme) {
             await window.reloadTheme();
        } else {
             location.reload();
        }

      } catch (err) {
        console.error('❌ Error guardando:', err);
        alert('Error al guardar: ' + err.message);
      } finally {
        btn.innerHTML = originalText;
        btn.disabled = false;
      }
    }

    getVal(id) {
      return document.getElementById(id)?.value || '';
    }
  }

  // Exportar inicializador
  window.SiteConfigModule = new SiteConfigModule();
})();
