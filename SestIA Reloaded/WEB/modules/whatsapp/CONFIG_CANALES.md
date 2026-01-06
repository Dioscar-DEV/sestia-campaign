# Configuración de Canales de WhatsApp

## Descripción General

El módulo de WhatsApp ahora carga dinámicamente los canales desde la tabla `instancias.instancias_inputs` de Supabase. Esto permite gestionar múltiples cuentas de WhatsApp Business sin necesidad de editar código.

## Estructura de la Tabla

La tabla `instancias_inputs` tiene los siguientes campos relevantes:

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | BIGINT | ID auto-incremental |
| `canal` | TEXT | Tipo de canal (debe ser "whatsapp") |
| `key` | TEXT | Credenciales separadas por comas |
| `nameid` | TEXT | Identificador único del canal |
| `custom_name` | TEXT | Nombre descriptivo que aparece en el selector |
| `meta_id` | TEXT | ID del teléfono de Meta (opcional) |
| `status` | TEXT | Estado: 'test', 'live', u 'off' |

## Formato del Campo `key`

El campo `key` debe contener los valores separados por comas en el siguiente orden:

```
token, phone_id
```

### Ejemplo:

```
EAAGl2ZBBtZABoBAPxxx..., 114235551234567
```

**Importante:** Los valores van directamente, sin llaves ni etiquetas.

## Cómo Agregar un Nuevo Canal

### Opción 1: Desde la interfaz de Supabase

1. Abre tu proyecto de Supabase
2. Ve a la tabla `instancias.instancias_inputs`
3. Haz clic en "Insert" → "Insert row"
4. Completa los campos:
   - **canal:** `whatsapp`
   - **key:** `TU_TOKEN, TU_PHONE_ID`
   - **nameid:** `fibex_sofia_6696` (identificador único)
   - **custom_name:** `Fibex Telecom - Sofía 6696 WhatsApp` (nombre descriptivo)
   - **meta_id:** `114235551234567` (opcional)
   - **status:** `live` o `test`

### Opción 2: Con SQL

```sql
INSERT INTO instancias.instancias_inputs (
  canal,
  key,
  nameid,
  custom_name,
  meta_id,
  status
) VALUES (
  'whatsapp',
  'EAAGl2ZBBtZABoBAPxxx..., 114235551234567',
  'fibex_sofia_6696',
  'Fibex Telecom - Sofía 6696 WhatsApp',
  '114235551234567',
  'live'
);
```

## Estados de Canal

- **`live`**: Canal activo en producción. Se muestra en el selector.
- **`test`**: Canal en pruebas. También se muestra en el selector.
- **`off`**: Canal desactivado. NO aparece en el selector.

## Obtener las Credenciales

### Token Permanente

1. Ve a [Meta Business Manager](https://business.facebook.com/)
2. Configuración → System Users
3. Selecciona o crea un System User
4. Genera un token con los permisos necesarios:
   - `whatsapp_business_messaging`
   - `whatsapp_business_management`
5. **Importante:** Selecciona "Never expires" para token permanente
6. Copia el token generado

### Phone ID

1. En Meta Business Manager
2. Ve a WhatsApp → API Setup
3. Selecciona tu número de teléfono
4. Copia el "Phone number ID"

## Uso en la Aplicación

Una vez configurados los canales en la base de datos:

1. El usuario abre el módulo de WhatsApp
2. Ve un selector "Seleccionar Canal de Envío"
3. Al seleccionar un canal, los campos Token y Phone ID se auto-completan
4. Solo necesita configurar la URL de API y el nombre de la plantilla
5. Puede guardar la configuración para futuras campañas

## Ventajas del Sistema

✅ **Multi-cuenta:** Gestiona múltiples números de WhatsApp desde una sola interfaz

✅ **Centralizado:** Todas las credenciales en un solo lugar (base de datos)

✅ **Seguro:** No hay credenciales hardcodeadas en el código

✅ **Flexible:** Activa/desactiva canales sin desplegar código

✅ **Fácil:** El usuario solo selecciona del dropdown, no necesita copiar/pegar tokens

## Troubleshooting

### El selector está vacío

- Verifica que hay filas en `instancias_inputs` con `canal = 'whatsapp'`
- Verifica que el `status` sea `'live'` o `'test'`, no `'off'`
- Revisa la consola del navegador para errores de Supabase

### Error al cargar canales

- Verifica que las políticas RLS permitan lectura en `instancias.instancias_inputs`
- Verifica que el usuario esté autenticado
- Revisa los permisos del esquema `instancias`

### Los campos no se auto-completan

- Verifica que el campo `key` tenga el formato correcto: `token, phone_id`
- Revisa la consola para ver qué datos se están parseando
- Asegúrate de que los valores en `key` no tengan espacios extras al inicio/final
