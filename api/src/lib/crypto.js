import crypto from 'crypto';

const key = Buffer.from(process.env.TOKEN_ENC_KEY || '', 'hex');
if (!key || key.length !== 32) {
  console.warn('TOKEN_ENC_KEY must be 32 bytes hex; using insecure fallback for dev');
}

export function encrypt(text) {
  const k = key.length === 32 ? key : crypto.randomBytes(32);
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', k, iv);
  const enc = Buffer.concat([cipher.update(text, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, enc]).toString('base64');
}

export function decrypt(b64) {
  const buf = Buffer.from(b64, 'base64');
  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(12, 28);
  const enc = buf.subarray(28);
  const k = key.length === 32 ? key : Buffer.alloc(32);
  const decipher = crypto.createDecipheriv('aes-256-gcm', k, iv);
  decipher.setAuthTag(tag);
  const dec = Buffer.concat([decipher.update(enc), decipher.final()]);
  return dec.toString('utf8');
}
