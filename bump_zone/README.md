# Bump Zone
fun collision game, knock opponents into the death zone

## Structure
- `client/`: Flutter project (frontend)
- `server/`: Node.js backend
- `server/public/`: Will hold Flutter web build output

## Setup
1. **Client**: Run `cd client && flutter pub get` to install dependencies.
2. **Server**: Run `cd server && npm install` to install dependencies.
3. **Local Testing**:
   - Client: `cd client && flutter run -d chrome`
   - Server: `cd server && node server.js`
4. **Deployment**:
   - Build Flutter web: `cd client && flutter build web`
   - Copy `client/build/web/` to `server/public/`
   - Upload `bump_zone/` to Glitch