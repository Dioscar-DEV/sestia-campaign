-- ================================================================
-- Script de Ejemplo: Insertar Canales de WhatsApp
-- ================================================================
-- Este script inserta datos de ejemplo en la tabla instancias_inputs
-- para configurar canales de WhatsApp en el sistema.
-- 
-- IMPORTANTE: Reemplaza los valores de ejemplo con tus credenciales reales
-- ================================================================

-- Ejemplo 1: Canal en producción (live)
INSERT INTO instancias.instancias_inputs (
  canal,
  key,
  nameid,
  custom_name,
  meta_id,
  status,
  output_options
) VALUES (
  'whatsapp',
  'EAAGl2ZBBtZABoBAPxxx..., 114235551234567',  -- Reemplazar con tu token y phone_id
  'fibex_sofia_6696_whatsapp',
  'Fibex Telecom - Sofía 6696 WhatsApp',
  '114235551234567',  -- Opcional: Phone ID de Meta
  'live',
  '{"text": true, "photo": true, "video": false, "gallery": false, "sticker": false, "document": true, "location": false}'::jsonb
) ON CONFLICT (nameid) DO NOTHING;

-- Ejemplo 2: Canal en pruebas (test)
INSERT INTO instancias.instancias_inputs (
  canal,
  key,
  nameid,
  custom_name,
  meta_id,
  status,
  output_options
) VALUES (
  'whatsapp',
  'EAAGl2ZBBtZABoBAPyyy..., 114235559876543',
  'fibex_credix_whatsapp',
  'Fibex Telecom - Credix WhatsApp',
  '114235559876543',
  'test',
  '{"text": true, "photo": true, "video": false, "gallery": false, "sticker": false, "document": true, "location": false}'::jsonb
) ON CONFLICT (nameid) DO NOTHING;

-- Ejemplo 3: Canal desactivado (off)
INSERT INTO instancias.instancias_inputs (
  canal,
  key,
  nameid,
  custom_name,
  meta_id,
  status,
  output_options
) VALUES (
  'whatsapp',
  'EAAGl2ZBBtZABoBAPzzz..., 114235553316789',
  'fibex_sofia_3316_whatsapp',
  'Fibex Telecom - Sofía 3316 Whatsapp',
  '114235553316789',
  'off',  -- Este NO aparecerá en el selector
  '{"text": true, "photo": true, "video": false, "gallery": false, "sticker": false, "document": false, "location": false}'::jsonb
) ON CONFLICT (nameid) DO NOTHING;

-- ================================================================
-- Consulta para verificar los canales insertados
-- ================================================================

SELECT 
  id,
  canal,
  nameid,
  custom_name,
  status,
  created_at
FROM instancias.instancias_inputs
WHERE canal = 'whatsapp'
ORDER BY custom_name;

-- ================================================================
-- Actualizar un canal existente
-- ================================================================

-- Cambiar estado de un canal
-- UPDATE instancias.instancias_inputs
-- SET status = 'live'
-- WHERE nameid = 'fibex_sofia_6696_whatsapp';

-- Actualizar credenciales de un canal
-- UPDATE instancias.instancias_inputs
-- SET key = 'NUEVO_TOKEN, NUEVO_PHONE_ID'
-- WHERE nameid = 'fibex_sofia_6696_whatsapp';

-- ================================================================
-- Eliminar un canal (usar con precaución)
-- ================================================================

-- DELETE FROM instancias.instancias_inputs
-- WHERE nameid = 'nombre_del_canal';
