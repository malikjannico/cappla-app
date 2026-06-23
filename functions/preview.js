const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const LOGO_URL = 'https://app-dev.cappla.de/favicon.png?v=1.0.1';

function loadTemplate(templateName, variables) {
  const templatePath = path.join(__dirname, 'templates', `${templateName}.html`);
  if (!fs.existsSync(templatePath)) {
    throw new Error(`Template not found: ${templatePath}`);
  }
  let content = fs.readFileSync(templatePath, 'utf8');
  const allVars = { logoUrl: LOGO_URL, ...variables };
  for (const [key, value] of Object.entries(allVars)) {
    content = content.replaceAll(`{{${key}}}`, value);
  }
  return content;
}

const templates = [
  {
    name: 'activation',
    vars: { resetLink: 'https://app-dev.cappla.de/#/reset-password?email=user.name@app-dev.cappla.de' }
  },
  {
    name: 'reset_code',
    vars: { code: '123456' }
  },
  {
    name: 'password_updated',
    vars: {}
  }
];

const outputDir = path.join(__dirname, 'preview_output');
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

console.log('Compiling email templates...');

templates.forEach(t => {
  try {
    const html = loadTemplate(t.name, t.vars);
    const outPath = path.join(outputDir, `${t.name}_preview.html`);
    fs.writeFileSync(outPath, html, 'utf8');
    console.log(`Generated preview for "${t.name}" at: ${outPath}`);
    
    // Open in browser
    const command = process.platform === 'darwin' ? `open "${outPath}"` :
                    process.platform === 'win32' ? `start "" "${outPath}"` :
                    `xdg-open "${outPath}"`;
    exec(command, (err) => {
      if (err) {
        console.error(`Failed to open preview in browser: ${err.message}`);
      } else {
        console.log(`Opened "${t.name}" in browser.`);
      }
    });
  } catch (err) {
    console.error(`Error generating preview for ${t.name}:`, err.message);
  }
});
