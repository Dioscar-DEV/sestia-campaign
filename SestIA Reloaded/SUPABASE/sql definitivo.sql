-- ==============================================================================
-- SESTIA - SISTEMA MODULAR DE GESTIÓN
-- SQL DEFINITIVO (ORGANIZADO Y COMENTADO)
-- ==============================================================================
-- 
-- ⚠️ PRINCIPIO FUNDAMENTAL DE PERMISOLOGÍA
-- El sistema NO filtra por roles, SOLO por permisos.
-- 
-- Secuencia de verificación:
-- 1. ¿Usuario autenticado?
-- 2. ¿El rol del usuario tiene el permiso X? (role_permissions)
-- 3. ¿Si no, el usuario específico tiene el permiso X? (user_permissions)
-- 
-- Resultado: TRUE o FALSE si el permiso existe para:
-- - El rol del usuario (desde role_permissions), O
-- - El permiso específico asignado al usuario (desde user_permissions)
-- 
-- NUNCA verificar roles directamente en políticas RLS o funciones RPC.
-- Siempre usar permisos específicos.
--
-- ==============================================================================
-- SCRIPT SQL IDEMPOTENTE
-- ==============================================================================
-- Este script es completamente idempotente: puede ejecutarse múltiples veces
-- sin errores, tanto en bases de datos nuevas como en bases de datos existentes.
-- 
-- Todas las funciones incluyen DROP FUNCTION IF EXISTS antes de CREATE OR REPLACE
-- Todas las tablas usan CREATE TABLE IF NOT EXISTS
-- Todas las políticas usan DROP POLICY IF EXISTS antes de CREATE POLICY
-- Todos los índices usan CREATE INDEX IF NOT EXISTS
-- Todos los triggers usan DROP TRIGGER IF EXISTS antes de CREATE TRIGGER
-- Todos los INSERT usan ON CONFLICT DO NOTHING
-- ==============================================================================

-- [SECCIÓN 1] EXTENSIONES Y CONFIGURACIÓN BASE
-- ==============================================================================

-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
-- Extensión para actualizar columnas de timestamp automáticamente desde triggers
CREATE EXTENSION IF NOT EXISTS "moddatetime" SCHEMA extensions;
-- Extensión para tareas programadas (cron jobs)
CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA extensions;

-- [SECCIÓN 2] ESQUEMAS Y PERMISOS GLOBALES
-- ==============================================================================
-- Se crean los esquemas al principio para evitar errores de referencia cruzada.

-- 2.1 Esquema INSTANCIAS (Módulos CMS y Agente)
CREATE SCHEMA IF NOT EXISTS instancias;
GRANT USAGE ON SCHEMA instancias TO service_role;
GRANT USAGE ON SCHEMA instancias TO authenticated, anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA instancias GRANT ALL PRIVILEGES ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA instancias GRANT ALL PRIVILEGES ON TABLES TO authenticated, anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA instancias GRANT ALL PRIVILEGES ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA instancias GRANT ALL PRIVILEGES ON SEQUENCES TO authenticated, anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA instancias GRANT ALL PRIVILEGES ON FUNCTIONS TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA instancias GRANT ALL PRIVILEGES ON FUNCTIONS TO authenticated, anon;

-- 2.2 Esquema KPIDATA (Métricas y Telemetría)
CREATE SCHEMA IF NOT EXISTS kpidata;
GRANT USAGE ON SCHEMA kpidata TO service_role;
GRANT USAGE ON SCHEMA kpidata TO authenticated, anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA kpidata GRANT ALL PRIVILEGES ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA kpidata GRANT ALL PRIVILEGES ON TABLES TO authenticated, anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA kpidata GRANT ALL PRIVILEGES ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA kpidata GRANT ALL PRIVILEGES ON SEQUENCES TO authenticated, anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA kpidata GRANT ALL PRIVILEGES ON FUNCTIONS TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA kpidata GRANT ALL PRIVILEGES ON FUNCTIONS TO authenticated, anon;

-- 2.3 Esquema MODULES (Extensiones personalizadas)
CREATE SCHEMA IF NOT EXISTS modules;
GRANT USAGE ON SCHEMA modules TO service_role;
GRANT USAGE ON SCHEMA modules TO authenticated, anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA modules GRANT ALL PRIVILEGES ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA modules GRANT ALL PRIVILEGES ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA modules GRANT ALL PRIVILEGES ON FUNCTIONS TO service_role;

-- [SECCIÓN 3] CORE: AUTENTICACIÓN, USUARIOS Y ROLES
-- ==============================================================================

-- 3.1 Tablas Core
CREATE TABLE IF NOT EXISTS profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'user',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS roles (
    role_key VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS permissions (
    perm_key VARCHAR(100) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    module VARCHAR(50) DEFAULT 'general',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS role_permissions (
    role_key VARCHAR(50) REFERENCES roles(role_key) ON DELETE CASCADE,
    perm_key VARCHAR(100) REFERENCES permissions(perm_key) ON DELETE CASCADE,
    PRIMARY KEY (role_key, perm_key)
);

CREATE TABLE IF NOT EXISTS user_permissions (
    user_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    perm_key VARCHAR(100) REFERENCES permissions(perm_key) ON DELETE CASCADE,
    granted_by UUID REFERENCES profiles(user_id),
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, perm_key)
);

-- 3.2 Datos Semilla (Roles y Permisos)
INSERT INTO roles (role_key, name, description) VALUES 
('user', 'Usuario', 'Usuario básico del sistema'),
('admin', 'Administrador', 'Administrador con acceso completo'),
('superadmin', 'Super Administrador', 'Acceso completo al sistema y configuración')
ON CONFLICT (role_key) DO NOTHING;

INSERT INTO permissions (perm_key, name, description, module) VALUES 
-- Home
('home.view', 'Ver Inicio', 'Acceso al módulo de inicio', 'home'),
-- Users
('users.view', 'Ver Usuarios', 'Ver lista de usuarios', 'users'),
('users.manage', 'Gestionar Usuarios', 'Crear, editar y eliminar usuarios', 'users'),
('users.invite', 'Enviar Invitaciones', 'Enviar invitaciones por email a nuevos usuarios', 'users'),
('users.create', 'Crear Usuarios', 'Crear nuevos usuarios en el sistema', 'users'),
('users.edit', 'Editar Usuarios', 'Editar información de usuarios existentes', 'users'),
('users.delete', 'Eliminar Usuarios', 'Eliminar usuarios del sistema', 'users'),
('users.permissions', 'Gestionar Permisos', 'Asignar y revocar permisos de usuarios', 'users'),
-- Indice
('indice.view', 'Ver Índice', 'Ver contenido del índice', 'indice'),
('indice.manage', 'Gestionar Índice', 'Crear, editar y eliminar contenido del índice', 'indice'),
('indice.create', 'Crear Contenido', 'Crear nuevo contenido en el índice', 'indice'),
('indice.edit', 'Editar Contenido', 'Editar contenido existente del índice', 'indice'),
('indice.delete', 'Eliminar Contenido', 'Eliminar contenido del índice', 'indice'),
-- Invitations
('invitations.view', 'Ver Invitaciones', 'Ver invitaciones pendientes', 'invitations'),
('invitations.manage', 'Gestionar Invitaciones', 'Crear y cancelar invitaciones', 'invitations'),
('invitations.cancel', 'Cancelar Invitaciones', 'Cancelar invitaciones pendientes', 'invitations'),
-- Agente IA
('agent.view', 'Ver Agente', 'Ver configuración y estado del agente IA', 'agent'),
('agent.manage', 'Gestionar Agente', 'Crear/editar configuración, tareas y encuestas del agente', 'agent'),
('agent.logs', 'Ver Logs del Agente', 'Acceder a trazas y telemetría del agente', 'agent'),
('agent.run', 'Ejecutar Agente', 'Lanzar/forzar ejecuciones y pruebas del agente', 'agent'),
('agent.contacts.view', 'Ver Contactos IA', 'Ver lista de contactos del agente', 'agent'),
('agent.contacts.manage', 'Gestionar Contactos IA', 'Editar contactos del agente', 'agent'),
('agent.livechat.view', 'Ver Livechat', 'Acceso al módulo de chat en vivo', 'agent'),
('agent.livechat.manage', 'Gestionar Livechat', 'Interactuar en el chat en vivo', 'agent'),
('agent.config.view', 'Ver Configuración Agente', 'Ver configuración del agente', 'agent'),
('agent.config.manage', 'Gestionar Configuración Agente', 'Editar configuración del agente', 'agent'),
('agent.tasks.view', 'Ver Tareas Agente', 'Ver lista de tareas del agente', 'agent'),
('agent.tasks.manage', 'Gestionar Tareas Agente', 'Crear y editar tareas del agente', 'agent')
ON CONFLICT (perm_key) DO NOTHING;

INSERT INTO role_permissions (role_key, perm_key) VALUES 
-- User
('user', 'home.view'),
('user', 'indice.view'),
-- Admin
('admin', 'home.view'),
('admin', 'users.view'),
('admin', 'users.manage'),
('admin', 'indice.view'),
('admin', 'indice.manage'),
('admin', 'invitations.view'),
('admin', 'invitations.manage'),
('admin', 'agent.view'),
('admin', 'agent.manage'),
('admin', 'agent.logs'),
('admin', 'agent.run'),
('admin', 'agent.contacts.view'),
('admin', 'agent.contacts.manage'),
('admin', 'agent.livechat.view'),
('admin', 'agent.livechat.manage'),
('admin', 'agent.config.view'),
('admin', 'agent.config.manage'),
('admin', 'agent.tasks.view'),
('admin', 'agent.tasks.manage'),
-- Superadmin (Todos)
('superadmin', 'home.view'),
('superadmin', 'users.view'),
('superadmin', 'users.manage'),
('superadmin', 'indice.view'),
('superadmin', 'indice.manage'),
('superadmin', 'invitations.view'),
('superadmin', 'invitations.manage'),
('superadmin', 'agent.view'),
('superadmin', 'agent.manage'),
('superadmin', 'agent.logs'),
('superadmin', 'agent.run'),
('superadmin', 'agent.contacts.view'),
('superadmin', 'agent.contacts.manage'),
('superadmin', 'agent.livechat.view'),
('superadmin', 'agent.livechat.manage'),
('superadmin', 'agent.config.view'),
('superadmin', 'agent.config.manage'),
('superadmin', 'agent.tasks.view'),
('superadmin', 'agent.tasks.manage')
ON CONFLICT (role_key, perm_key) DO NOTHING;

-- 3.3 Funciones RPC Core (Permisos y Perfiles)
DROP FUNCTION IF EXISTS get_profile_by_user_id(UUID) CASCADE;
CREATE OR REPLACE FUNCTION get_profile_by_user_id(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'success', true,
        'user_id', p.user_id,
        'email', p.email,
        'role', p.role,
        'name', p.name
    ) INTO result
    FROM profiles p
    WHERE p.user_id = p_user_id;
    RETURN COALESCE(result, jsonb_build_object('success', false, 'error', 'Usuario no encontrado'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS get_permissions_by_user_id(UUID) CASCADE;
CREATE OR REPLACE FUNCTION get_permissions_by_user_id(p_user_id UUID)
RETURNS TEXT[] AS $$
DECLARE
    user_perms TEXT[];
    current_user_id UUID;
    user_role VARCHAR;
BEGIN
    current_user_id := auth.uid();
    IF current_user_id IS NULL THEN RAISE EXCEPTION 'Usuario no autenticado'; END IF;
    IF current_user_id != p_user_id AND NOT current_user_has_permission('users.permissions') THEN
        RAISE EXCEPTION 'No tienes permiso para ver los permisos de otro usuario.';
    END IF;
    SELECT role INTO user_role FROM profiles WHERE user_id = p_user_id;
    IF user_role = 'superadmin' THEN
        SELECT ARRAY_AGG(perm_key) INTO user_perms FROM permissions;
        RETURN COALESCE(user_perms, ARRAY[]::TEXT[]);
    END IF;
    WITH role_perms AS (
        SELECT DISTINCT rp.perm_key FROM profiles p
        JOIN role_permissions rp ON p.role = rp.role_key
        WHERE p.user_id = p_user_id
    ),
    user_specific_perms AS (
        SELECT DISTINCT up.perm_key FROM user_permissions up
        WHERE up.user_id = p_user_id
    )
    SELECT ARRAY(SELECT DISTINCT perm_key FROM role_perms UNION SELECT DISTINCT perm_key FROM user_specific_perms) INTO user_perms;
    RETURN COALESCE(user_perms, ARRAY[]::TEXT[]);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS get_my_permissions() CASCADE;
CREATE OR REPLACE FUNCTION get_my_permissions()
RETURNS TEXT[] AS $$
BEGIN
    RETURN get_permissions_by_user_id(auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS user_has_permission(UUID, VARCHAR) CASCADE;
CREATE OR REPLACE FUNCTION user_has_permission(p_user_id UUID, p_perm_key VARCHAR(100))
RETURNS BOOLEAN AS $$
DECLARE
    user_role VARCHAR;
BEGIN
    IF p_user_id IS NULL THEN RETURN FALSE; END IF;
    SELECT role INTO user_role FROM profiles WHERE user_id = p_user_id;
    IF user_role = 'superadmin' THEN RETURN TRUE; END IF;
    RETURN EXISTS (
        SELECT 1 FROM get_permissions_by_user_id(p_user_id) AS perms
        WHERE p_perm_key = ANY(perms)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS current_user_has_permission(VARCHAR) CASCADE;
CREATE OR REPLACE FUNCTION current_user_has_permission(p_perm_key VARCHAR(100))
RETURNS BOOLEAN AS $$
DECLARE
    current_user_id UUID;
BEGIN
    current_user_id := auth.uid();
    IF current_user_id IS NULL THEN RETURN FALSE; END IF;
    RETURN user_has_permission(current_user_id, p_perm_key);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3.4 Triggers Core
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (user_id, email, name, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
        COALESCE(NEW.raw_user_meta_data->>'role', 'user')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP FUNCTION IF EXISTS public.validate_profile_update() CASCADE;
CREATE OR REPLACE FUNCTION public.validate_profile_update()
RETURNS TRIGGER AS $$
DECLARE
    has_edit_permission BOOLEAN;
    has_manage_permission BOOLEAN;
BEGIN
    SELECT current_user_has_permission('users.edit') INTO has_edit_permission;
    SELECT current_user_has_permission('users.manage') INTO has_manage_permission;
    IF NEW.user_id = auth.uid() AND NOT (has_edit_permission OR has_manage_permission) THEN
        IF NEW.role != OLD.role THEN RAISE EXCEPTION 'No tienes permiso para cambiar tu rol.'; END IF;
        IF NEW.user_id != OLD.user_id THEN RAISE EXCEPTION 'No puedes cambiar tu user_id'; END IF;
        IF NEW.email != OLD.email THEN RAISE EXCEPTION 'No tienes permiso para cambiar tu email.'; END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS validate_profile_update_trigger ON profiles;
CREATE TRIGGER validate_profile_update_trigger
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION public.validate_profile_update();

-- 3.5 RLS Core
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_permissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Users can view own profile or users.view" ON profiles;
CREATE POLICY "Users can view own profile or users.view" ON profiles
    FOR SELECT TO authenticated
    USING (((SELECT auth.uid()) = user_id) OR current_user_has_permission('users.view'));

DROP POLICY IF EXISTS "Admins can update profiles" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users with users.manage can manage profiles" ON profiles;
DROP POLICY IF EXISTS "Users can edit own profile or users.edit" ON profiles;
CREATE POLICY "Users can edit own profile or users.edit" ON profiles
    FOR UPDATE TO authenticated
    USING (((SELECT auth.uid()) = user_id) OR current_user_has_permission('users.edit') OR current_user_has_permission('users.manage'))
    WITH CHECK (((SELECT auth.uid()) = user_id) OR current_user_has_permission('users.edit') OR current_user_has_permission('users.manage'));

DROP POLICY IF EXISTS "Authenticated users can view roles" ON roles;
CREATE POLICY "Authenticated users can view roles" ON roles FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated users can view permissions" ON permissions;
CREATE POLICY "Authenticated users can view permissions" ON permissions FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admins can manage permissions" ON permissions;
DROP POLICY IF EXISTS "Users with users.permissions can manage permissions" ON permissions;
CREATE POLICY "Users with users.permissions can manage permissions" ON permissions
    FOR ALL TO authenticated
    USING (current_user_has_permission('users.permissions'))
    WITH CHECK (current_user_has_permission('users.permissions'));

DROP POLICY IF EXISTS "Authenticated users can view role_permissions" ON role_permissions;
CREATE POLICY "Authenticated users can view role_permissions" ON role_permissions FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users with users.permissions can manage role_permissions" ON role_permissions;
CREATE POLICY "Users with users.permissions can manage role_permissions" ON role_permissions
    FOR ALL TO authenticated
    USING (current_user_has_permission('users.permissions'))
    WITH CHECK (current_user_has_permission('users.permissions'));

DROP POLICY IF EXISTS "Users can view own permissions" ON user_permissions;
CREATE POLICY "Users can view own permissions" ON user_permissions FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Admins can manage user permissions" ON user_permissions;
DROP POLICY IF EXISTS "Users with users.permissions can manage user_permissions" ON user_permissions;
CREATE POLICY "Users with users.permissions can manage user_permissions" ON user_permissions
    FOR ALL TO authenticated
    USING (current_user_has_permission('users.permissions'))
    WITH CHECK (current_user_has_permission('users.permissions'));

-- [SECCIÓN 4] CORE: CONFIGURACIÓN FRONTEND
-- ==============================================================================

CREATE TABLE IF NOT EXISTS frontconfig (
    id SERIAL PRIMARY KEY,
    key VARCHAR(100) UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

INSERT INTO frontconfig (key, value, description) VALUES 
('theme', '{
    "brandName": "SestIA",
    "brandShort": "SestIA",
    "logoUrl": "assets/logo.svg",
    "bannerUrl": "assets/banner.svg",
    "bannerText": "Sistema Modular de Gestión",
    "footer": {
        "text": "© 2025 SestIA. Todos los derechos reservados.",
        "links": [
            {"label": "Términos", "href": "javascript:openTermsModal()"},
            {"label": "Privacidad", "href": "javascript:openPrivacyModal()"}
        ]
    },
    "colors": {
        "bg": "#ffffff",
        "panel": "#ffffff",
        "panel2": "#f8fafc",
        "text": "#0f172a",
        "muted": "#64748b",
        "brand": "#3b82f6",
        "accent": "#1e40af",
        "danger": "#dc2626",
        "dangerLight": "#b91c1c",
        "success": "#10b981",
        "successLight": "#34d399",
        "warning": "#f59e0b",
        "warningLight": "#d97706",
        "info": "#0ea5e9",
        "infoLight": "#38bdf8",
        "brandLight": "#60a5fa",
        "border": "#e2e8f0"
    },
    "shadows": {
        "sm": "0 1px 2px 0 rgba(0, 0, 0, 0.05)",
        "md": "0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)",
        "lg": "0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)"
    }
}', 'Configuración visual del tema del sitio'),
('site', '{
    "title": "SestIA - Sistema Modular",
    "description": "Sistema modular de gestión empresarial",
    "version": "1.0.0",
    "author": "SestIA Team",
    "contact": "contacto@sestia.com"
}', 'Configuración general del sitio')
ON CONFLICT (key) DO NOTHING;

ALTER TABLE frontconfig ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view frontconfig" ON frontconfig;
CREATE POLICY "Public can view frontconfig" ON frontconfig FOR SELECT TO anon, authenticated USING (key IN ('theme', 'site'));

DROP POLICY IF EXISTS "Authenticated users can view frontconfig" ON frontconfig;
CREATE POLICY "Authenticated users can view frontconfig" ON frontconfig FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Admins can manage frontconfig" ON frontconfig;
DROP POLICY IF EXISTS "Authenticated users can manage frontconfig" ON frontconfig;
CREATE POLICY "Authenticated users can manage frontconfig" ON frontconfig FOR ALL TO authenticated USING (true);

-- [SECCIÓN 5] MÓDULO: INVITACIONES
-- ==============================================================================

CREATE TABLE IF NOT EXISTS invitations (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL REFERENCES roles(role_key),
    invited_by UUID REFERENCES profiles(user_id),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    accepted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    name VARCHAR(255),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired', 'cancelled'))
);

DROP FUNCTION IF EXISTS accept_invitation_native(VARCHAR) CASCADE;
CREATE OR REPLACE FUNCTION accept_invitation_native(p_email VARCHAR(255))
RETURNS JSON AS $$
DECLARE
    invitation_record RECORD;
    user_record RECORD;
BEGIN
    SELECT * INTO invitation_record FROM invitations WHERE email = p_email AND accepted_at IS NULL AND expires_at > NOW() ORDER BY created_at DESC LIMIT 1;
    IF NOT FOUND THEN RETURN json_build_object('success', false, 'error', 'No se encontró una invitación válida'); END IF;
    IF auth.uid() IS NULL THEN RETURN json_build_object('success', false, 'error', 'Usuario no autenticado'); END IF;
    SELECT * INTO user_record FROM auth.users WHERE id = auth.uid() AND email = p_email;
    IF NOT FOUND THEN RETURN json_build_object('success', false, 'error', 'El email no coincide'); END IF;
    
    UPDATE profiles SET role = invitation_record.role, name = COALESCE(invitation_record.name, profiles.name, user_record.email), updated_at = NOW() WHERE user_id = auth.uid();
    IF NOT FOUND THEN
        INSERT INTO profiles (user_id, email, name, role) VALUES (auth.uid(), p_email, COALESCE(invitation_record.name, user_record.email), invitation_record.role)
        ON CONFLICT (user_id) DO UPDATE SET role = invitation_record.role, name = COALESCE(invitation_record.name, profiles.name, user_record.email), updated_at = NOW();
    END IF;
    UPDATE invitations SET accepted_at = NOW(), status = 'accepted' WHERE id = invitation_record.id;
    RETURN json_build_object('success', true, 'message', 'Invitación aceptada', 'role', invitation_record.role);
EXCEPTION WHEN OTHERS THEN RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS cancel_invitation_complete(INTEGER, VARCHAR) CASCADE;
CREATE OR REPLACE FUNCTION cancel_invitation_complete(p_invitation_id INTEGER, p_user_email VARCHAR(255))
RETURNS JSON AS $$
DECLARE
    current_user_role TEXT;
    invitation_record RECORD;
    user_record RECORD;
    result JSON;
BEGIN
    SELECT role INTO current_user_role FROM profiles WHERE user_id = auth.uid();
    IF current_user_role != 'superadmin' THEN RETURN json_build_object('success', false, 'error', 'Solo superadmin puede cancelar'); END IF;
    SELECT * INTO invitation_record FROM invitations WHERE id = p_invitation_id AND email = p_user_email;
    IF NOT FOUND THEN RETURN json_build_object('success', false, 'error', 'Invitación no encontrada'); END IF;
    SELECT * INTO user_record FROM auth.users WHERE email = p_user_email;
    BEGIN
        DELETE FROM invitations WHERE id = p_invitation_id;
        DELETE FROM profiles WHERE email = p_user_email;
        result := json_build_object('success', true, 'message', 'Invitación cancelada');
    EXCEPTION WHEN OTHERS THEN result := json_build_object('success', false, 'error', SQLERRM);
    END;
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage invitations" ON invitations;
DROP POLICY IF EXISTS "Users with invitations.manage can manage invitations" ON invitations;
CREATE POLICY "Users with invitations.manage can manage invitations" ON invitations
    FOR ALL TO authenticated
    USING (current_user_has_permission('invitations.manage'))
    WITH CHECK (current_user_has_permission('invitations.manage'));

DROP POLICY IF EXISTS "Users with invitations.view can view invitations" ON invitations;
CREATE POLICY "Users with invitations.view can view invitations" ON invitations
    FOR SELECT TO authenticated
    USING (current_user_has_permission('invitations.view'));

-- [SECCIÓN 6] MÓDULO: ÍNDICE (CMS)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS instancias.INDICE (
    ID SERIAL PRIMARY KEY,
    TEMA VARCHAR(255) NOT NULL,
    DESCRIPCION TEXT,
    CONTENIDO TEXT,
    ETIQUETAS TEXT,
    COLOR VARCHAR(7) DEFAULT '#3b82f6',
    ACTIVO BOOLEAN DEFAULT true,
    AVAILABLE_FOR_AI BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS instancias.INDICE_LOG (
    id SERIAL PRIMARY KEY,
    INDICE_ID INTEGER REFERENCES instancias.INDICE(ID) ON DELETE CASCADE,
    user_email VARCHAR(255),
    action VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

DROP FUNCTION IF EXISTS indice_list() CASCADE;
CREATE OR REPLACE FUNCTION indice_list()
RETURNS TABLE (ID INTEGER, TEMA VARCHAR, DESCRIPCION TEXT, CONTENIDO TEXT, ETIQUETAS TEXT, COLOR VARCHAR, ACTIVO BOOLEAN, AVAILABLE_FOR_AI BOOLEAN, created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ) AS $$
BEGIN
    RETURN QUERY SELECT i.ID, i.TEMA, i.DESCRIPCION, i.CONTENIDO, i.ETIQUETAS, i.COLOR, i.ACTIVO, i.AVAILABLE_FOR_AI, i.created_at, i.updated_at FROM instancias.INDICE i ORDER BY i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS indice_upsert(INTEGER, VARCHAR, TEXT, TEXT, TEXT, VARCHAR, BOOLEAN, BOOLEAN) CASCADE;
CREATE OR REPLACE FUNCTION indice_upsert(p_id INTEGER DEFAULT NULL, p_tema VARCHAR DEFAULT NULL, p_descripcion TEXT DEFAULT NULL, p_contenido TEXT DEFAULT NULL, p_etiquetas TEXT DEFAULT NULL, p_color VARCHAR DEFAULT NULL, p_activo BOOLEAN DEFAULT NULL, p_available_for_ai BOOLEAN DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
    result_id INTEGER;
    user_email TEXT;
BEGIN
    SELECT email INTO user_email FROM profiles WHERE user_id = auth.uid();
    IF p_id IS NOT NULL THEN
        UPDATE instancias.INDICE SET TEMA = COALESCE(p_tema, TEMA), DESCRIPCION = COALESCE(p_descripcion, DESCRIPCION), CONTENIDO = COALESCE(p_contenido, CONTENIDO), ETIQUETAS = COALESCE(p_etiquetas, ETIQUETAS), COLOR = COALESCE(p_color, COLOR), ACTIVO = COALESCE(p_activo, ACTIVO), AVAILABLE_FOR_AI = COALESCE(p_available_for_ai, AVAILABLE_FOR_AI), updated_at = NOW() WHERE ID = p_id RETURNING ID INTO result_id;
        INSERT INTO instancias.INDICE_LOG (INDICE_ID, user_email, action) VALUES (p_id, user_email, 'updated');
    ELSE
        INSERT INTO instancias.INDICE (TEMA, DESCRIPCION, CONTENIDO, ETIQUETAS, COLOR, ACTIVO, AVAILABLE_FOR_AI) VALUES (p_tema, p_descripcion, p_contenido, p_etiquetas, p_color, p_activo, p_available_for_ai) RETURNING ID INTO result_id;
        INSERT INTO instancias.INDICE_LOG (INDICE_ID, user_email, action) VALUES (result_id, user_email, 'created');
    END IF;
    RETURN jsonb_build_object('success', true, 'id', result_id);
EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS indice_delete(INTEGER) CASCADE;
CREATE OR REPLACE FUNCTION indice_delete(p_id INTEGER)
RETURNS JSONB AS $$
DECLARE user_email TEXT;
BEGIN
    SELECT email INTO user_email FROM profiles WHERE user_id = auth.uid();
    INSERT INTO instancias.INDICE_LOG (INDICE_ID, user_email, action) VALUES (p_id, user_email, 'deleted');
    DELETE FROM instancias.INDICE WHERE ID = p_id;
    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

ALTER TABLE instancias.INDICE ENABLE ROW LEVEL SECURITY;
ALTER TABLE instancias.INDICE_LOG ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view active indice" ON instancias.INDICE;
CREATE POLICY "Authenticated users can view active indice" ON instancias.INDICE FOR SELECT USING (auth.role() = 'authenticated' AND ACTIVO = true);

DROP POLICY IF EXISTS "Users with indice.manage can manage indice" ON instancias.INDICE;
CREATE POLICY "Users with indice.manage can manage indice" ON instancias.INDICE FOR ALL USING (current_user_has_permission('indice.manage'));

DROP POLICY IF EXISTS "Users with indice.manage can view indice_log" ON instancias.INDICE_LOG;
CREATE POLICY "Users with indice.manage can view indice_log" ON instancias.INDICE_LOG FOR SELECT USING (current_user_has_permission('indice.manage'));

-- [SECCIÓN 7] MÓDULO: AGENTE IA - CONFIGURACIÓN Y CORE
-- ==============================================================================

CREATE TABLE IF NOT EXISTS instancias.agent_config (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    i_channels_webhook TEXT NOT NULL,
    i_core_webhook TEXT NOT NULL,
    c_channels_webhook TEXT NOT NULL,
    c_instance_webhook TEXT NOT NULL,
    i_blacklist BOOLEAN NOT NULL,
    i_tasks BOOLEAN NOT NULL,
    eleven_labs JSONB NOT NULL DEFAULT '{"key": "", "model": "eleven_multilingual_v2", "voice_id": "", "output_format": "mp3_44100_96"}'::jsonb,
    context_length SMALLINT NOT NULL DEFAULT 15,
    owner_list TEXT[] NOT NULL DEFAULT '{}'::text[],
    multimedia_preprocessing BOOLEAN NOT NULL DEFAULT false,
    multimedia_processing_config JSONB NOT NULL DEFAULT '{"models": {"audio": "google/gemini-2.5-flash-lite", "image": "z-ai/glm-4.6v", "video": "z-ai/glm-4.6v", "document": "google/gemini-2.5-flash-lite"}, "detail_tier": 3}'::jsonb
);

CREATE TABLE IF NOT EXISTS instancias.agent_vars (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    agent_owner_name TEXT NULL,
    agent_owner_knowledge TEXT NULL,
    agent_name TEXT NULL,
    agent_personality TEXT NULL,
    agent_knowledge TEXT NULL,
    agent_stickerlist JSONB[] NULL,
    agent_gallerylist JSONB[] NULL
);

CREATE TABLE IF NOT EXISTS instancias.agent_core_list (
    core_id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc-4:00'::text),
    core_name TEXT NOT NULL,
    core_chat TEXT NOT NULL UNIQUE,
    core_instructions TEXT NULL,
    core_restrictions TEXT NULL,
    core_memories JSONB[] NOT NULL DEFAULT ARRAY['{"id":0,"admin":"Smart Automata","content":"Debo responder siempre en español","created_at":"2025-11-19 19:57:48.598309+00"}'::jsonb]::jsonb[],
    core_channel TEXT NOT NULL,
    core_description TEXT NULL,
    default_messaging_mode TEXT NOT NULL DEFAULT 'timeout_cancel'::text CHECK (default_messaging_mode IN ('timeout_cancel', 'timeout_aprove', 'aprove_all', 'cancel_all')),
    messaging_programming JSONB NOT NULL DEFAULT '[]'::jsonb,
    timeout_ms NUMERIC NOT NULL DEFAULT '300000'::numeric
);

CREATE TABLE IF NOT EXISTS instancias.blacklist (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_chat TEXT NULL,
    nombre TEXT NULL
);

CREATE TABLE IF NOT EXISTS instancias.input_channels (
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc-4:00'::text),
    name TEXT NOT NULL PRIMARY KEY,
    output_supports JSONB NOT NULL DEFAULT '{"text": true, "photo": false, "video": false, "gallery": false, "sticker": false, "document": false, "location": false}'::jsonb,
    core_supports JSONB NOT NULL DEFAULT '{"dm": false, "group": false, "support": false}'::jsonb
);

CREATE TABLE IF NOT EXISTS instancias.cores_inputs (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    canal TEXT NOT NULL REFERENCES instancias.input_channels (name),
    key TEXT NOT NULL,
    nameid TEXT NOT NULL UNIQUE,
    custom_name TEXT NOT NULL UNIQUE,
    output_options JSONB NOT NULL DEFAULT '{"text": true, "photo": false, "video": false, "gallery": false, "sticker": false, "document": false, "location": false}'::jsonb
);

CREATE TABLE IF NOT EXISTS instancias.instancias_inputs (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    canal TEXT NOT NULL REFERENCES instancias.input_channels (name),
    key TEXT NOT NULL,
    nameid TEXT NOT NULL UNIQUE,
    custom_name TEXT NOT NULL UNIQUE,
    output_options JSONB NOT NULL DEFAULT '{"text": true, "photo": false, "video": false, "gallery": false, "sticker": false, "document": false, "location": false}'::jsonb,
    meta_id TEXT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'test'::text CHECK (status IN ('test', 'live', 'off'))
);

CREATE TABLE IF NOT EXISTS instancias.input_channels_test (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc-4:00'::text),
    recieve BOOLEAN NOT NULL DEFAULT FALSE,
    recieve_data JSON NOT NULL DEFAULT '{}'::json,
    sending BOOLEAN NOT NULL DEFAULT FALSE,
    sending_data JSON NOT NULL DEFAULT '{}'::json,
    channel_nameid TEXT NOT NULL REFERENCES instancias.instancias_inputs (nameid)
);

-- [SECCIÓN 8] MÓDULO: AGENTE IA - OPERATIVO (CONTACTOS, TAREAS, CHAT)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS instancias.agent_contact_list (
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_id TEXT NOT NULL PRIMARY KEY,
    contact_nickname TEXT,
    contact_name TEXT,
    contact_phone TEXT,
    contact_email TEXT,
    contact_channel TEXT,
    contact_system_channel TEXT NOT NULL,
    contact_agent_name TEXT,
    contact_last_channel TEXT,
    contact_verify BOOLEAN NOT NULL DEFAULT FALSE,
    contact_friendship INTEGER NOT NULL DEFAULT 0,
    contact_prompt_count BIGINT NOT NULL DEFAULT 0,
    contact_chat TEXT NOT NULL,
    contact_docid TEXT
);

CREATE TABLE IF NOT EXISTS instancias.agent_surveys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    survey_type TEXT CHECK (survey_type IN ('opinion', 'facts', 'satisfaction', 'diagnostic')) NOT NULL DEFAULT 'facts',
    schema JSONB NOT NULL CHECK (schema ? 'fields' AND jsonb_typeof(schema->'fields') = 'array'),
    version INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS instancias.agent_task_list (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    task_type TEXT CHECK (task_type IN ('survey', 'notification', 'data_collection', 'action')) NOT NULL,
    survey_id UUID REFERENCES instancias.agent_surveys(id) ON DELETE SET NULL,
    global_status TEXT CHECK (global_status IN ('borrador', 'asignada', 'pausada', 'completada', 'cancelada')) NOT NULL DEFAULT 'borrador',
    priority INTEGER NOT NULL DEFAULT 0,
    due_date TIMESTAMPTZ,
    assignment_filters JSONB,
    metadata JSONB,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    CONSTRAINT task_survey_requires_survey_id CHECK (task_type != 'survey' OR survey_id IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS instancias.agent_task_assign (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES instancias.agent_task_list(id) ON DELETE CASCADE,
    contact_user_id TEXT NOT NULL REFERENCES instancias.agent_contact_list(user_id) ON DELETE CASCADE,
    individual_status TEXT CHECK (individual_status IN ('asignado', 'iniciado', 'completado', 'fallado', 'omitido')) NOT NULL DEFAULT 'asignado',
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    result JSONB,
    failure_reason TEXT,
    notes TEXT,
    answered_fields TEXT[] DEFAULT ARRAY[]::TEXT[],
    completion_pct NUMERIC(5,2) DEFAULT 0.00,
    CONSTRAINT unique_task_contact UNIQUE(task_id, contact_user_id),
    CONSTRAINT started_after_assigned CHECK (started_at IS NULL OR started_at >= assigned_at),
    CONSTRAINT completed_after_started CHECK (completed_at IS NULL OR (started_at IS NOT NULL AND completed_at >= started_at))
);

CREATE OR REPLACE VIEW instancias.v_tasks_summary AS
SELECT t.id, t.title, t.task_type, t.global_status, t.priority, t.due_date, s.name AS survey_name,
    COUNT(a.id) AS total_assigned,
    COUNT(a.id) FILTER (WHERE a.individual_status = 'asignado') AS pending_count,
    COUNT(a.id) FILTER (WHERE a.individual_status = 'iniciado') AS in_progress_count,
    COUNT(a.id) FILTER (WHERE a.individual_status = 'completado') AS completed_count,
    COUNT(a.id) FILTER (WHERE a.individual_status = 'fallado') AS failed_count,
    t.created_at, t.updated_at
FROM instancias.agent_task_list t
LEFT JOIN instancias.agent_surveys s ON t.survey_id = s.id
LEFT JOIN instancias.agent_task_assign a ON t.id = a.task_id
GROUP BY t.id, s.name;

CREATE TABLE IF NOT EXISTS instancias.agent_callback_list (
    callback_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc-4:00'::text),
    endpoint TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS instancias.agent_callback_history (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    callback_id UUID NOT NULL REFERENCES instancias.agent_callback_list(callback_id) ON DELETE CASCADE,
    executed_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc-4:00'::text),
    user_id TEXT REFERENCES instancias.agent_contact_list(user_id),
    channel_id TEXT REFERENCES instancias.instancias_inputs(nameid),
    data TEXT,
    payload_sent JSONB,
    response_status INTEGER,
    response_body TEXT,
    status TEXT CHECK (status IN ('success', 'failure', 'pending'))
);

DROP FUNCTION IF EXISTS instancias.complete_or_report_agent_task(TEXT, UUID, JSONB, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION instancias.complete_or_report_agent_task(p_contact_user_id TEXT, p_task_id UUID, p_answers JSONB DEFAULT NULL, p_notes TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
    v_assignment_id UUID;
    v_task_type TEXT;
    v_survey_schema JSONB;
    v_field_ids TEXT[];
    v_answered_now TEXT[];
    v_invalid_ids TEXT[];
    v_existing_answers TEXT[];
    v_all_answered TEXT[];
    v_required_questions TEXT[];
    v_total_questions INT;
    v_answered_required INT;
    v_pct NUMERIC(5,2);
    v_status TEXT;
BEGIN
    SELECT a.id, t.task_type, s.schema, a.answered_fields INTO v_assignment_id, v_task_type, v_survey_schema, v_existing_answers
    FROM instancias.agent_task_assign a JOIN instancias.agent_task_list t ON a.task_id = t.id LEFT JOIN instancias.agent_surveys s ON t.survey_id = s.id
    WHERE a.contact_user_id = p_contact_user_id AND a.task_id = p_task_id;

    IF v_assignment_id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'assignment_not_found'); END IF;

    IF v_task_type = 'survey' THEN
        IF p_answers IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'answers_required'); END IF;
        IF v_survey_schema IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'schema_missing'); END IF;
        v_field_ids := ARRAY(SELECT f->>'id' FROM jsonb_array_elements(v_survey_schema->'fields') f);
        v_answered_now := ARRAY(SELECT jsonb_object_keys(p_answers));
        v_invalid_ids := ARRAY(SELECT id FROM unnest(v_answered_now) id WHERE id NOT IN (SELECT * FROM unnest(v_field_ids)));
        IF array_length(v_invalid_ids, 1) IS NOT NULL THEN RETURN jsonb_build_object('success', false, 'error', 'invalid_field_id', 'invalid_ids', v_invalid_ids); END IF;
        v_all_answered := (SELECT ARRAY(SELECT DISTINCT unnest(COALESCE(v_existing_answers, ARRAY[]::TEXT[]) || v_answered_now)));
        v_required_questions := ARRAY(SELECT f->>'id' FROM jsonb_array_elements(v_survey_schema->'fields') f WHERE COALESCE((f->>'required')::BOOLEAN, FALSE));
        v_total_questions := COALESCE(array_length(v_required_questions, 1), 0);
        v_answered_required := (SELECT COUNT(*) FROM unnest(v_required_questions) rq WHERE rq = ANY(v_all_answered));
        IF v_total_questions > 0 THEN v_pct := round(v_answered_required::NUMERIC / v_total_questions * 100.0, 2); ELSE v_pct := 100.00; END IF;
        v_status := CASE WHEN v_pct = 100.0 THEN 'completado' ELSE 'parcial' END;
        UPDATE instancias.agent_task_assign SET result = COALESCE(result, '{}'::jsonb) || jsonb_build_object('answers', COALESCE(result->'answers', '{}'::jsonb) || p_answers), answered_fields = v_all_answered, completion_pct = v_pct, individual_status = CASE WHEN v_pct = 100.0 THEN 'completado' ELSE individual_status END, started_at = CASE WHEN v_pct = 100.0 AND started_at IS NULL THEN NOW() ELSE started_at END, completed_at = CASE WHEN v_pct = 100.0 THEN NOW() ELSE completed_at END, notes = COALESCE(p_notes, notes) WHERE id = v_assignment_id;
        RETURN jsonb_build_object('success', true, 'type', v_task_type, 'completion_pct', v_pct, 'status', v_status);
    END IF;

    IF v_task_type IN ('data_collection', 'notification', 'action') THEN
        IF p_answers IS NOT NULL THEN RETURN jsonb_build_object('success', false, 'error', 'answers_forbidden'); END IF;
        IF (p_notes IS NULL OR LENGTH(TRIM(p_notes)) = 0) THEN RETURN jsonb_build_object('success', false, 'error', 'notes_required'); END IF;
        UPDATE instancias.agent_task_assign SET individual_status = 'completado', notes = COALESCE(p_notes, notes), started_at = COALESCE(started_at, NOW()), completed_at = NOW() WHERE id = v_assignment_id;
        RETURN jsonb_build_object('success', true, 'type', v_task_type, 'status', 'completado');
    END IF;
    RETURN jsonb_build_object('success', false, 'error', 'unknown_task_type', 'type', v_task_type);
EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- RLS Agente
ALTER TABLE instancias.agent_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE instancias.agent_vars ENABLE ROW LEVEL SECURITY;
ALTER TABLE instancias.blacklist ENABLE ROW LEVEL SECURITY;
ALTER TABLE instancias.input_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE instancias.agent_contact_list ENABLE ROW LEVEL SECURITY;
ALTER TABLE instancias.agent_surveys ENABLE ROW LEVEL SECURITY;
ALTER TABLE instancias.agent_task_list ENABLE ROW LEVEL SECURITY;
ALTER TABLE instancias.agent_task_assign ENABLE ROW LEVEL SECURITY;
ALTER TABLE instancias.agent_core_list ENABLE ROW LEVEL SECURITY;
ALTER TABLE instancias.cores_inputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE instancias.instancias_inputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE instancias.input_channels_test ENABLE ROW LEVEL SECURITY;
ALTER TABLE instancias.agent_callback_list ENABLE ROW LEVEL SECURITY;
ALTER TABLE instancias.agent_callback_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users with agent.contacts.view can view contacts" ON instancias.agent_contact_list;
CREATE POLICY "Users with agent.contacts.view can view contacts" ON instancias.agent_contact_list FOR SELECT TO authenticated USING (public.current_user_has_permission('agent.contacts.view'));

DROP POLICY IF EXISTS "Users with agent.contacts.manage can manage contacts" ON instancias.agent_contact_list;
CREATE POLICY "Users with agent.contacts.manage can manage contacts" ON instancias.agent_contact_list FOR ALL TO authenticated USING (public.current_user_has_permission('agent.contacts.manage')) WITH CHECK (public.current_user_has_permission('agent.contacts.manage'));

DROP POLICY IF EXISTS "Users with agent.tasks.view can view tasks" ON instancias.agent_task_list;
CREATE POLICY "Users with agent.tasks.view can view tasks" ON instancias.agent_task_list FOR SELECT TO authenticated USING (public.current_user_has_permission('agent.tasks.view'));

DROP POLICY IF EXISTS "Users with agent.tasks.manage can manage tasks" ON instancias.agent_task_list;
CREATE POLICY "Users with agent.tasks.manage can manage tasks" ON instancias.agent_task_list FOR ALL TO authenticated USING (public.current_user_has_permission('agent.tasks.manage')) WITH CHECK (public.current_user_has_permission('agent.tasks.manage'));

DROP POLICY IF EXISTS "Users with agent.tasks.view can view assignments" ON instancias.agent_task_assign;
CREATE POLICY "Users with agent.tasks.view can view assignments" ON instancias.agent_task_assign FOR SELECT TO authenticated USING (public.current_user_has_permission('agent.tasks.view'));

DROP POLICY IF EXISTS "Users with agent.tasks.manage can manage assignments" ON instancias.agent_task_assign;
CREATE POLICY "Users with agent.tasks.manage can manage assignments" ON instancias.agent_task_assign FOR ALL TO authenticated USING (public.current_user_has_permission('agent.tasks.manage')) WITH CHECK (public.current_user_has_permission('agent.tasks.manage'));

GRANT ALL PRIVILEGES ON TABLE instancias.agent_core_list TO service_role;
GRANT ALL PRIVILEGES ON TABLE instancias.cores_inputs TO service_role;
GRANT ALL PRIVILEGES ON TABLE instancias.instancias_inputs TO service_role;
GRANT ALL PRIVILEGES ON TABLE instancias.input_channels_test TO service_role;
GRANT ALL PRIVILEGES ON TABLE instancias.agent_callback_list TO service_role;
GRANT ALL PRIVILEGES ON TABLE instancias.agent_callback_history TO service_role;

-- [SECCIÓN 9] MÓDULO: KPIDATA (MÉTRICAS Y TELEMETRÍA)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS kpidata.conversations (
    chat_id TEXT NOT NULL PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc-4:00'::text),
    title TEXT NOT NULL DEFAULT 'Deconocido'::text,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ NULL,
    user_assign UUID NULL REFERENCES profiles (user_id),
    role_assign TEXT NULL REFERENCES roles (role_key)
);

CREATE TABLE IF NOT EXISTS kpidata.multimedia_incoming (
    media_id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc-4:00'::text),
    type TEXT NOT NULL,
    filename TEXT NOT NULL,
    directory TEXT NOT NULL,
    size NUMERIC NULL,
    chat_id TEXT NOT NULL REFERENCES kpidata.conversations (chat_id),
    user_id TEXT NOT NULL REFERENCES instancias.agent_contact_list (user_id),
    user_channel TEXT NOT NULL REFERENCES instancias.instancias_inputs (nameid),
    system_channel TEXT NOT NULL REFERENCES instancias.input_channels (name),
    prompt_id TEXT NULL,
    ext TEXT NULL,
    bucket_id TEXT NULL
);

CREATE TABLE IF NOT EXISTS kpidata.messages (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc-4:00'::text),
    role TEXT NOT NULL,
    content TEXT NULL,
    message_type TEXT NOT NULL,
    media_url TEXT NULL,
    tokens BIGINT NULL,
    chat_id TEXT NOT NULL REFERENCES kpidata.conversations (chat_id),
    media_id UUID NULL REFERENCES kpidata.multimedia_incoming (media_id),
    media_directory TEXT NULL,
    user_id TEXT NOT NULL REFERENCES instancias.agent_contact_list (user_id)
);

CREATE TABLE IF NOT EXISTS kpidata.multimedia_processing (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    media_id UUID NOT NULL REFERENCES kpidata.multimedia_incoming (media_id),
    type TEXT NOT NULL,
    metadata JSONB NULL,
    prompt_tokens NUMERIC NULL,
    completion_tokens NUMERIC NULL,
    total_tokens NUMERIC NULL,
    cost NUMERIC NULL,
    details_analyzed TEXT NULL
);

CREATE TABLE IF NOT EXISTS kpidata.iainterna (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc-4:00'::text),
    "from" TEXT NULL,
    "to" TEXT NULL,
    content TEXT NULL
);

CREATE TABLE IF NOT EXISTS kpidata.tools (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'utc-4:00'::text),
    tool TEXT NULL,
    result TEXT NULL,
    status TEXT NULL
);

ALTER TABLE kpidata.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE kpidata.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE kpidata.multimedia_incoming ENABLE ROW LEVEL SECURITY;
ALTER TABLE kpidata.multimedia_processing ENABLE ROW LEVEL SECURITY;
ALTER TABLE kpidata.iainterna ENABLE ROW LEVEL SECURITY;
ALTER TABLE kpidata.tools ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users with agent.livechat.view can view conversations" ON kpidata.conversations;
CREATE POLICY "Users with agent.livechat.view can view conversations" ON kpidata.conversations FOR SELECT TO authenticated USING (public.current_user_has_permission('agent.livechat.view'));

DROP POLICY IF EXISTS "Users with agent.livechat.view can view messages" ON kpidata.messages;
CREATE POLICY "Users with agent.livechat.view can view messages" ON kpidata.messages FOR SELECT TO authenticated USING (public.current_user_has_permission('agent.livechat.view'));

-- [SECCIÓN 10] UTILIDADES Y MANTENIMIENTO
-- ==============================================================================

DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
CREATE OR REPLACE FUNCTION update_updated_at_column() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_indice_updated_at ON instancias.INDICE;
CREATE TRIGGER update_indice_updated_at BEFORE UPDATE ON instancias.INDICE FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_frontconfig_updated_at ON frontconfig;
CREATE TRIGGER update_frontconfig_updated_at BEFORE UPDATE ON frontconfig FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS handle_surveys_updated_at ON instancias.agent_surveys;
CREATE TRIGGER handle_surveys_updated_at BEFORE UPDATE ON instancias.agent_surveys FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime(updated_at);

DROP TRIGGER IF EXISTS handle_tasks_updated_at ON instancias.agent_task_list;
CREATE TRIGGER handle_tasks_updated_at BEFORE UPDATE ON instancias.agent_task_list FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime(updated_at);

CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_user_permissions_user_id ON user_permissions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_permissions_perm_key ON user_permissions(perm_key);
CREATE INDEX IF NOT EXISTS idx_invitations_email ON invitations(email);
CREATE INDEX IF NOT EXISTS idx_invitations_status ON invitations(status);
CREATE INDEX IF NOT EXISTS idx_invitations_expires_at ON invitations(expires_at);
CREATE INDEX IF NOT EXISTS idx_indice_activo ON instancias.INDICE(ACTIVO);
CREATE INDEX IF NOT EXISTS idx_indice_created_at ON instancias.INDICE(created_at);
CREATE INDEX IF NOT EXISTS idx_indice_log_indice_id ON instancias.INDICE_LOG(INDICE_ID);
CREATE INDEX IF NOT EXISTS idx_indice_log_created_at ON instancias.INDICE_LOG(created_at);
CREATE INDEX IF NOT EXISTS idx_surveys_active ON instancias.agent_surveys(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_surveys_type ON instancias.agent_surveys(survey_type);
CREATE INDEX IF NOT EXISTS idx_surveys_schema_gin ON instancias.agent_surveys USING GIN (schema);
CREATE INDEX IF NOT EXISTS idx_tasks_global_status ON instancias.agent_task_list(global_status);
CREATE INDEX IF NOT EXISTS idx_tasks_type ON instancias.agent_task_list(task_type);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON instancias.agent_task_list(priority DESC) WHERE global_status = 'asignada';
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON instancias.agent_task_list(due_date) WHERE due_date IS NOT NULL AND global_status IN ('asignada', 'pausada');
CREATE INDEX IF NOT EXISTS idx_tasks_survey_id ON instancias.agent_task_list(survey_id) WHERE survey_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_filters_gin ON instancias.agent_task_list USING GIN (assignment_filters);
CREATE INDEX IF NOT EXISTS idx_tasks_created_by ON instancias.agent_task_list(created_by);
CREATE INDEX IF NOT EXISTS idx_assign_contact ON instancias.agent_task_assign(contact_user_id, individual_status);
CREATE INDEX IF NOT EXISTS idx_assign_task ON instancias.agent_task_assign(task_id, individual_status);
CREATE INDEX IF NOT EXISTS idx_assign_status ON instancias.agent_task_assign(individual_status);
CREATE INDEX IF NOT EXISTS idx_assign_assigned_at ON instancias.agent_task_assign(assigned_at);
CREATE INDEX IF NOT EXISTS idx_assign_result_gin ON instancias.agent_task_assign USING GIN (result);
CREATE INDEX IF NOT EXISTS idx_assign_contact_pending ON instancias.agent_task_assign(contact_user_id, individual_status, assigned_at) WHERE individual_status IN ('asignado', 'iniciado');
CREATE INDEX IF NOT EXISTS idx_callback_history_callback_id ON instancias.agent_callback_history(callback_id);
CREATE INDEX IF NOT EXISTS idx_callback_history_executed_at ON instancias.agent_callback_history(executed_at);
CREATE INDEX IF NOT EXISTS idx_callback_history_user_id ON instancias.agent_callback_history(user_id);

-- [SECCIÓN 11] STORAGE
-- ==============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES 
    ('media-incoming',  'media-incoming',  FALSE, NULL, NULL),
    ('media-generated', 'media-generated', FALSE, 52428800, ARRAY['image/jpeg','image/png','image/webp','application/pdf','audio/mpeg','audio/wav']),
    ('media-special',   'media-special',   FALSE, NULL, NULL),
    ('media-published', 'media-published', TRUE,  NULL, NULL),
    ('public-assets',   'public-assets',   TRUE,  NULL, NULL)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public, file_size_limit = EXCLUDED.file_size_limit, allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Public read media-published" ON storage.objects;
DROP POLICY IF EXISTS "Public read public-assets" ON storage.objects;
DROP POLICY IF EXISTS "Read private media buckets" ON storage.objects;
DROP POLICY IF EXISTS "Manage media buckets" ON storage.objects;

CREATE POLICY "Public read media-published" ON storage.objects FOR SELECT TO anon, authenticated USING (bucket_id = 'media-published');
CREATE POLICY "Public read public-assets" ON storage.objects FOR SELECT TO anon, authenticated USING (bucket_id = 'public-assets');
CREATE POLICY "Read private media buckets" ON storage.objects FOR SELECT TO authenticated USING (public.current_user_has_permission('agent.view') AND bucket_id IN ('media-incoming','media-generated','media-special'));
CREATE POLICY "Manage media buckets" ON storage.objects FOR ALL TO authenticated USING (public.current_user_has_permission('agent.manage') AND bucket_id IN ('media-incoming','media-generated','media-special','media-published','public-assets')) WITH CHECK (public.current_user_has_permission('agent.manage') AND bucket_id IN ('media-incoming','media-generated','media-special','media-published','public-assets'));

DO $main$
DECLARE v_job_name text := 'purge_media_ttl_30d'; v_job_id int;
BEGIN
    SELECT jobid INTO v_job_id FROM cron.job WHERE jobname = v_job_name;
    IF v_job_id IS NOT NULL THEN PERFORM cron.unschedule(v_job_id); END IF;
    PERFORM cron.schedule(v_job_name, '15 3 * * *', $$ DELETE FROM storage.objects WHERE bucket_id IN ('media-incoming', 'media-generated') AND created_at < (now() - interval '30 days'); $$);
END $main$;

-- [SECCIÓN 12] INICIALIZACIÓN FINAL
-- ==============================================================================

DROP FUNCTION IF EXISTS validate_admin_user_exists() CASCADE;
CREATE OR REPLACE FUNCTION validate_admin_user_exists() RETURNS BOOLEAN AS $$
DECLARE admin_user_id UUID;
BEGIN
    SELECT id INTO admin_user_id FROM auth.users WHERE email = 'admin@smartautomatai.com';
    IF admin_user_id IS NULL THEN
        RAISE EXCEPTION '❌ ERROR: Usuario admin@smartautomatai.com no encontrado en auth.users. Por favor créalo manualmente.';
        RETURN FALSE;
    ELSE
        RAISE NOTICE '✅ Usuario admin@smartautomatai.com encontrado.';
        RETURN TRUE;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$ BEGIN IF NOT validate_admin_user_exists() THEN RAISE EXCEPTION 'Script detenido: Usuario administrador no encontrado.'; END IF; END $$;

DROP FUNCTION IF EXISTS create_default_admin() CASCADE;
CREATE OR REPLACE FUNCTION create_default_admin() RETURNS void AS $$
DECLARE admin_user_id UUID;
BEGIN
    SELECT id INTO admin_user_id FROM auth.users WHERE email = 'admin@smartautomatai.com';
    IF admin_user_id IS NOT NULL THEN
        INSERT INTO profiles (user_id, email, name, role) VALUES (admin_user_id, 'admin@smartautomatai.com', 'Administrador', 'superadmin')
        ON CONFLICT (user_id) DO UPDATE SET role = 'superadmin', name = 'Administrador', email = 'admin@smartautomatai.com';
        RAISE NOTICE '✅ Usuario administrador configurado.';
    ELSE
        RAISE EXCEPTION '❌ Usuario admin@smartautomatai.com no encontrado.';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT create_default_admin();

DROP FUNCTION IF EXISTS invite_admin_user() CASCADE;
CREATE OR REPLACE FUNCTION invite_admin_user() RETURNS JSONB AS $$
DECLARE invitation_id INTEGER;
BEGIN
    INSERT INTO invitations (email, role, invited_by, expires_at) VALUES ('admin@smartautomatai.com', 'superadmin', NULL, NOW() + INTERVAL '7 days') RETURNING id INTO invitation_id;
    RETURN jsonb_build_object('success', true, 'invitation_id', invitation_id, 'message', 'Invitación creada');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- FIN DEL SCRIPT
