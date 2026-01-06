# Instrucciones SQL para Módulo WhatsApp

## ⚙️ Configuración de Permisos en Supabase

Ejecuta el siguiente SQL en tu **Supabase SQL Editor**:

```sql
-- 1. Crear permisos para el módulo WhatsApp
INSERT INTO permissions (perm_key, name, description, module) VALUES 
('modules.whatsapp.view', 'Ver WhatsApp Masivo', 'Acceso al módulo de envío masivo de WhatsApp', 'whatsapp'),
('modules.whatsapp.send', 'Enviar WhatsApp Masivo', 'Permiso para realizar envíos masivos', 'whatsapp')
ON CONFLICT (perm_key) DO NOTHING;

-- 2. Asignar permisos al rol admin
INSERT INTO role_permissions (role_key, perm_key) VALUES 
('admin', 'modules.whatsapp.view'),
('admin', 'modules.whatsapp.send')
ON CONFLICT (role_key, perm_key) DO NOTHING;

-- 3. Asignar permisos al rol superadmin
INSERT INTO role_permissions (role_key, perm_key) VALUES 
('superadmin', 'modules.whatsapp.view'),
('superadmin', 'modules.whatsapp.send')
ON CONFLICT (role_key, perm_key) DO NOTHING;

-- 4. Verificar que los permisos se crearon correctamente
SELECT * FROM permissions WHERE module = 'whatsapp';

-- 5. Verificar asignación a roles
SELECT rp.*, p.name 
FROM role_permissions rp
JOIN permissions p ON rp.perm_key = p.perm_key
WHERE p.module = 'whatsapp';
```

## ✅ Verificación

Después de ejecutar el SQL, deberías ver:

### Permisos creados:
- `modules.whatsapp.view` - Ver WhatsApp Masivo
- `modules.whatsapp.send` - Enviar WhatsApp Masivo

### Roles con acceso:
- `admin` - Ambos permisos
- `superadmin` - Ambos permisos

## 🔄 Próximos Pasos

1. ✅ Permisos configurados
2. 🔄 Refrescar la aplicación en el navegador
3. 🔄 Iniciar sesión con un usuario admin o superadmin
4. 🔄 Buscar "WhatsApp Masivo" en el menú dropdown
5. 🔄 Configurar los datos de la API
6. 🔄 Cargar el archivo CSV de prueba

## 📁 Archivo de Prueba

Usa el archivo `modules/whatsapp/ejemplo.csv` para hacer pruebas:

```csv
numero,variable1,variable2,url_imagen
584121234567,Juan Pérez,25.00 USD,https://i.imgur.com/example1.jpg
584129876543,María López,30.00 USD,
584125555555,Pedro García,15.50 USD,https://i.imgur.com/example2.jpg
```

## ⚠️ Nota Importante

Este módulo **NO** crea tablas en la base de datos. Toda la configuración se guarda en `localStorage` del navegador del usuario. Los envíos se realizan directamente a la API externa de WhatsApp.
