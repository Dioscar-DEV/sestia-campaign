
INSERT INTO instancia_sofia.instancias_inputs (
  canal,
  key,
  nameid,
  custom_name,
  output_options
) VALUES (
  14,
  'EAAGl2ZBBtZABoBAPxxx..., 114235551234567, 987654321098765',  -- Reemplazar con tu token, phone_id y idWaba
  'fibex_sofia_6696_whatsapp',
  'Fibex Telecom - Sofía 6696 WhatsApp',
  '{"text": true, "photo": true, "video": false, "gallery": false, "sticker": false, "document": true, "location": false}'::jsonb
) ON CONFLICT (nameid) DO NOTHING;

INSERT INTO instancia_sofia.instancias_inputs (
  canal,
  key,
  nameid,
  custom_name,
  output_options
) VALUES (
  14,
  'EAAGl2ZBBtZABoBAPyyy..., 114235559876543, 987654321012345',
  'fibex_credix_whatsapp',
  'Fibex Telecom - Credix WhatsApp',
  '{"text": true, "photo": true, "video": false, "gallery": false, "sticker": false, "document": true, "location": false}'::jsonb
) ON CONFLICT (nameid) DO NOTHING;

INSERT INTO instancia_sofia.instancias_inputs (
  canal,
  key,
  nameid,
  custom_name,
  output_options
) VALUES (
  14,
  'EAAGl2ZBBtZABoBAPzzz..., 114235553316789, 987654321099999',
  'fibex_sofia_3316_whatsapp',
  'Fibex Telecom - Sofía 3316 Whatsapp',
  '{"text": true, "photo": true, "video": false, "gallery": false, "sticker": false, "document": false, "location": false}'::jsonb
) ON CONFLICT (nameid) DO NOTHING;


SELECT 
  id,
  canal,
  nameid,
  custom_name,
  created_at
FROM instancia_sofia.instancias_inputs
WHERE canal = 14
ORDER BY custom_name;





