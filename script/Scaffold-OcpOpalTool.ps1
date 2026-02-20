<#
    Scaffold-OcpOpalTool.ps1

    Automation script to:
      - Ensure Node.js (>= 18), Yarn (classic), and Git are installed
      - Configure OCP CLI credentials and install @optimizely/ocp-cli
   

    USAGE (from repository root):
      - Open PowerShell
      
      Interactive setup (will prompt for ProjectName, ContactEmail, and ApiKey):
          .\setup\Scaffold-OcpOpalTool.ps1
      
      Run with custom metadata and API key:
          .\setup\Scaffold-OcpOpalTool.ps1 `
            -ProjectName "my-custom-tool" `
            -ContactEmail "developer@company.com" `
            -SupportUrl "https://github.com/company/my-custom-tool/issues" `
            -ApiKey "your-ocp-api-key-here"
      
      Example with minimal custom parameters:
          .\setup\Scaffold-OcpOpalTool.ps1 -ProjectName "mailchimp-integration" -ApiKey "ocp_abc123xyz"

    Optional parameters (will prompt if not provided or using defaults):
      -ProjectName   Name of the app directory to create (default: "ocp-opal-tool")
      -ContactEmail  Email to put in app.yml (default: "your.email@example.com")
      -SupportUrl    Support URL to put in app.yml (default: "https://github.com/yourusername/ocp-opal-tool/issues")
      -ApiKey        OCP API key; will be prompted if omitted
#>

param(
    [string]$ProjectName,
    [string]$ContactEmail,
    [string]$ApiKey,
    [string]$SupportUrl = "https://github.com/yourusername/ocp-opal-tool/issues",
    [string]$Vendor = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== OCP Opal Tool Setup ===" -ForegroundColor Cyan
Write-Host ""

if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    $ProjectName = Read-Host -Prompt "Enter project name"
    if ([string]::IsNullOrWhiteSpace($ProjectName)) {
        $ProjectName = "ocp-opal-tool"
    }
}

if ([string]::IsNullOrWhiteSpace($ContactEmail)) {
    $ContactEmail = Read-Host -Prompt "Enter contact email"
    if ([string]::IsNullOrWhiteSpace($ContactEmail)) {
        throw "Contact email is required."
    }
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = Read-Host -Prompt "Enter your OCP API key"
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        throw "API key is required."
    }
}

if ([string]::IsNullOrWhiteSpace($Vendor)) {
    $Vendor = Read-Host -Prompt "Enter vendor name (company or owner of this app)"
    if ([string]::IsNullOrWhiteSpace($Vendor)) {
        $Vendor = $ProjectName
    }
}

function Write-Section {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Command-Exists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Ensure-Node {
    Write-Section "Checking Node.js"

    if (Command-Exists "node") {
        $version = node --version
        Write-Host "Node.js is already installed. Version: $version"
        return
    }

    Write-Host "Node.js not found. Attempting to install via winget..." -ForegroundColor Yellow
    if (-not (Command-Exists "winget")) {
        Write-Host "winget is not available. Please install Node.js 18+ manually and re-run this script." -ForegroundColor Red
        throw "Node.js missing and winget not available."
    }

    winget install -e --id OpenJS.NodeJS.LTS -h --accept-package-agreements --accept-source-agreements

    if (-not (Command-Exists "node")) {
        throw "Node.js installation appears to have failed. Please install manually and re-run."
    }

    Write-Host "Node.js installed successfully. Version: $(node --version)"
}

function Ensure-Git {
    Write-Section "Checking Git"

    if (Command-Exists "git") {
        Write-Host "Git is already installed. Version: $(git --version)"
        return
    }

    Write-Host "Git not found. Attempting to install via winget..." -ForegroundColor Yellow
    if (-not (Command-Exists "winget")) {
        Write-Host "winget is not available. Please install Git manually and re-run this script." -ForegroundColor Red
        throw "Git missing and winget not available."
    }

    winget install -e --id Git.Git -h --accept-package-agreements --accept-source-agreements

    if (-not (Command-Exists "git")) {
        throw "Git installation appears to have failed. Please install manually and re-run."
    }

    Write-Host "Git installed successfully. Version: $(git --version)"
}

function Ensure-Yarn {
    Write-Section "Checking Yarn"

    if (Command-Exists "yarn") {
        Write-Host "Yarn is already installed. Version: $(yarn --version)"
        return
    }

    Write-Host "Yarn not found. Installing Yarn (classic) globally via npm..." -ForegroundColor Yellow
    if (-not (Command-Exists "npm")) {
        throw "npm not found even though Node.js should provide it. Please verify your Node installation."
    }

    npm install -g yarn

    if (-not (Command-Exists "yarn")) {
        throw "Yarn installation appears to have failed. Please install manually and re-run."
    }

    Write-Host "Yarn installed successfully. Version: $(yarn --version)"
}

function Ensure-Ocp-Credentials {
    Write-Section "Configuring OCP credentials"

    $ocpDir = Join-Path $env:USERPROFILE ".ocp"
    if (-not (Test-Path $ocpDir)) {
        New-Item -Path $ocpDir -ItemType "directory" -Force | Out-Null
        Write-Host "Created directory: $ocpDir"
    } else {
        Write-Host "OCP directory already exists: $ocpDir"
    }

    $credentialsPath = Join-Path $ocpDir "credentials.json"

    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        throw "API key is required."
    }

    $credObject = @{ apiKey = $ApiKey }
    $credJson = $credObject | ConvertTo-Json -Depth 2
    $credJson | Out-File $credentialsPath -Encoding utf8

    Write-Host "Updated OCP credentials at: $credentialsPath"
}

function Ensure-Ocp-Cli {
    Write-Section "Installing OCP CLI"

    Ensure-Yarn

    yarn global add @optimizely/ocp-cli

    $yarnBin = yarn global bin
    if ($env:Path -notlike "*$yarnBin*") {
        $env:Path += ";$yarnBin"
        Write-Host "Temporarily added Yarn global bin to PATH for this session: $yarnBin"
        Write-Host "If you want this permanently, add it to your user/system PATH."
    }

    if (-not (Command-Exists "ocp")) {
        Write-Host "Warning: ocp command still not found after installation. Check your PATH and Yarn global bin." -ForegroundColor Yellow
    } else {
        Write-Host "OCP CLI installed. Current account (if any):"
        try {
            ocp accounts whoami
        } catch {
            Write-Host "Could not run 'ocp accounts whoami' yet. Configure your account if required." -ForegroundColor Yellow
        }
    }
}

function Initialize-Project {
    Write-Section "Initializing OCP app project '$ProjectName'"

    $projectPath = Join-Path (Get-Location) $ProjectName

    if (-not (Test-Path $projectPath)) {
        New-Item -Path $projectPath -ItemType "directory" | Out-Null
        Write-Host "Created project directory: $projectPath"
    } else {
        Write-Host "Project directory already exists: $projectPath"
    }

    Push-Location $projectPath
    try {
        if (-not (Test-Path "package.json")) {
            Write-Host "Initializing npm project (npm init -y)..."
            npm init -y | Out-Null
        } else {
            Write-Host "package.json already exists; it will be updated."
        }

        Write-Section "Configuring package.json"
        $pkgJson = [ordered]@{
          name        = $ProjectName
          version     = "1.0.0"
          description = "$ProjectName - OCP Opal tool app"
          main        = "index.js"
          scripts     = [ordered]@{
            build = "yarn && npx rimraf dist && npx tsc && copyfiles app.yml dist && copyfiles --up 1 src/**/*.{yml,yaml} dist"
            lint  = "eslint src --ext .ts"
            test  = "exit 0"
          }
          keywords    = @()
          author      = ""
          license     = "ISC"
          type        = "commonjs"
          dependencies = [ordered]@{
            "@optimizely-opal/opal-tool-ocp-sdk" = "1.0.0-beta.10"
            "@zaiusinc/app-sdk"                 = "^2.3.0"
            "@zaiusinc/node-sdk"                = "^2.0.0"
            "axios"                             = "^1.13.5"
          }
          devDependencies = [ordered]@{
            "@types/node"                      = "^25.3.0"
            "@typescript-eslint/eslint-plugin" = "^8.56.0"
            "@typescript-eslint/parser"        = "^8.56.0"
            "copyfiles"                        = "^2.4.1"
            "eslint"                           = "^10.0.0"
            "rimraf"                           = "^6.1.3"
            "typescript"                       = "^5.9.3"
          }
        }
        $pkgJson | ConvertTo-Json -Depth 10 | Set-Content -Path "package.json" -Encoding UTF8

        Write-Section "Creating project structure"

        foreach ($dir in @(
            "src",
            "src\functions",
            "src\lifecycle",
            "forms",
            "assets",
            "assets\directory"
        )) {
            if (-not (Test-Path $dir)) {
                New-Item -Path $dir -ItemType "directory" | Out-Null
                Write-Host "Created directory: $dir"
            } else {
                Write-Host "Directory already exists: $dir"
            }
        }

        foreach ($file in @(
            "src\index.ts",
            "src\functions\OpalToolFunction.ts",
            "src\api-client.ts",
            "src\types.ts",
            "src\lifecycle\Lifecycle.ts",
            "app.yml",
            "forms\settings.yml",
            "tsconfig.json",
            ".eslintrc.json",
            "assets\icon.svg",
            "assets\logo.svg",
            "assets\directory\overview.md"
        )) {
            if (-not (Test-Path $file)) {
                New-Item -Path $file -ItemType "file" | Out-Null
                Write-Host "Created file: $file"
            } else {
                Write-Host "File already exists: $file"
            }
        }

        Write-Section "Scaffolding src\index.ts"
        @"
// For OCP Opal tools, the entry_point in app.yml points directly to the function class
// The OCP runtime will instantiate it with the Request parameter
// We just need to export the class
export { OpalToolFunction } from './functions/OpalToolFunction';

// Export lifecycle for OCP app lifecycle handling
export { Lifecycle } from './lifecycle/Lifecycle';
"@ | Set-Content -Path "src\index.ts" -Encoding UTF8

        Write-Section "Scaffolding src\types.ts"
        @'
export type AuthType = 'basic' | 'bearer' | 'none';

export interface ApiCredentials {
  apiUrl: string;
  /**
   * API key or token used for authentication.
   * Interpretation depends on authType (e.g. password for basic, token for bearer).
   */
  apiKey?: string;
  /**
   * Username for basic authentication. If omitted, a generic username will be used.
   */
  username?: string;
  /**
   * Authentication scheme to use for outgoing requests.
   * - "basic": HTTP Basic auth (default when apiKey is provided)
   * - "bearer": Bearer token auth
   * - "none": no Authorization header
   */
  authType?: AuthType;
}

export interface OptiIdAuthData {
  credentials: ApiCredentials;
}

export interface ToolParams {
  [key: string]: any;
}
'@ | Set-Content -Path "src\types.ts" -Encoding UTF8

        Write-Section "Scaffolding src\api-client.ts"
        @'
import axios, { AxiosInstance } from 'axios';
import { ApiCredentials } from './types';

export class ApiClient {
  private client: AxiosInstance;

  constructor(credentials: ApiCredentials) {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };

    const { apiUrl, apiKey, username, authType } = credentials;

    // Configure Authorization header based on authType
    const resolvedAuthType = authType ?? (apiKey ? 'basic' : 'none');

    if (resolvedAuthType !== 'none') {
      if (!apiKey) {
        throw new Error('apiKey is required when authType is not "none".');
      }

      if (resolvedAuthType === 'basic') {
        // Generic basic auth: username:apiKey (username can be anything if API ignores it)
        const user = username ?? 'api';
        const auth = Buffer.from(`${user}:${apiKey}`).toString('base64');
        headers['Authorization'] = `Basic ${auth}`;
      } else if (resolvedAuthType === 'bearer') {
        headers['Authorization'] = `Bearer ${apiKey}`;
      }
    }

    this.client = axios.create({
      baseURL: apiUrl,
      headers,
    });
  }

  async get(endpoint: string): Promise<any> {
    const response = await this.client.get(endpoint);
    return response.data;
  }

  async post(endpoint: string, data: any): Promise<any> {
    const response = await this.client.post(endpoint, data);
    return response.data;
  }

  async patch(endpoint: string, data: any): Promise<any> {
    const response = await this.client.patch(endpoint, data);
    return response.data;
  }

  async put(endpoint: string, data: any): Promise<any> {
    const response = await this.client.put(endpoint, data);
    return response.data;
  }

  async delete(endpoint: string): Promise<any> {
    const response = await this.client.delete(endpoint);
    return response.data;
  }
}
'@ | Set-Content -Path "src\api-client.ts" -Encoding UTF8

        Write-Section "Scaffolding src\lifecycle\Lifecycle.ts"
        @'
import { 
  Lifecycle as BaseLifecycle, 
  LifecycleResult, 
  LifecycleSettingsResult, 
  AuthorizationGrantResult,
  Request,
  storage
} from '@zaiusinc/app-sdk';

export class Lifecycle extends BaseLifecycle {
  async onInstall(): Promise<LifecycleResult> {
    try {
      console.log('Opal tool app installed');
      // Perform any initial setup tasks here
      // For example: initialize default settings, validate environment, etc.
      return { success: true };
    } catch (error: any) {
      console.error('Installation failed:', error);
      return { 
        success: false, 
        message: error.message || 'Failed to install the app' 
      };
    }
  }

  async onSettingsForm(section: string, action: string, formData: any): Promise<LifecycleSettingsResult> {
    const { api_url, api_key } = formData;
    
    const result = new LifecycleSettingsResult();
    
    if (!api_url) {
      result.addError('api_url', 'API URL is required');
    }
    
    if (!api_key) {
      result.addError('api_key', 'API Key is required');
    }
    
    // If there are errors, return them without saving
    if (!api_url || !api_key) {
      return result;
    }

    // Save to storage
    await storage.settings.put(section, formData);
    
    return result.addToast('success', 'Opal tool app credentials saved successfully!');
  }

  async onUpgrade(fromVersion: string): Promise<LifecycleResult> {
    try {
      console.log('Opal tool app upgraded from version:', fromVersion);
      // Perform upgrade tasks here (before functions are migrated)
      // For example: migrate data, update schema, etc.
      // All actions must be idempotent and backwards compatible
      return { success: true };
    } catch (error: any) {
      console.error('Upgrade failed:', error);
      return { 
        success: false, 
        message: error.message || 'Failed to upgrade the app' 
      };
    }
  }

  async onFinalizeUpgrade(fromVersion: string): Promise<LifecycleResult> {
    try {
      console.log('Opal tool app upgrade finalized from version:', fromVersion);
      // Perform final upgrade tasks here (after functions are migrated)
      // For example: register new functions, update configurations, etc.
      return { success: true };
    } catch (error: any) {
      console.error('Finalize upgrade failed:', error);
      return { 
        success: false, 
        message: error.message || 'Failed to finalize the upgrade' 
      };
    }
  }

  async onUninstall(): Promise<LifecycleResult> {
    try {
      console.log('Opal tool app uninstalled');   
      // Note: Settings and data are automatically cleaned up by the platform
      return { success: true };
    } catch (error: any) {
      console.error('Uninstall failed:', error);
      return { 
        success: false, 
        message: error.message || 'Failed to uninstall the app' 
      };
    }
  }

  async onAuthorizationRequest(section: string, formData: any): Promise<LifecycleSettingsResult> {
    const result = new LifecycleSettingsResult();
    
    try {
      console.log('Authorization requested for section:', section, formData);      
          
      // For now, return success (implement OAuth redirect as needed)
      return result.addToast('info', 'Authorization request processed');
    } catch (error: any) {
      console.error('Authorization request failed:', error);
      return result.addToast('danger', error.message || 'Failed to process authorization request');
    }
  }

  async onAuthorizationGrant(request: Request): Promise<AuthorizationGrantResult> {
    try {
      console.log('Authorization granted for Opal tool app');
    
      // Return success with redirect to settings section
      const result = new AuthorizationGrantResult('credentials');
      return result
        .addToast('success', 'Successfully authorized');
    } catch (error: any) {
      console.error('Authorization grant failed:', error);
      const result = new AuthorizationGrantResult('credentials');
      return result
        .addToast('danger', error.message || 'Failed to complete authorization');
    }
  }
}
'@ | Set-Content -Path "src\lifecycle\Lifecycle.ts" -Encoding UTF8

        Write-Section "Scaffolding src\functions\HealthFunctions.ts"
        @'
import { tool, ToolFunction } from '@optimizely-opal/opal-tool-ocp-sdk';
import { ApiClient } from '../api-client';
import { OptiIdAuthData, ToolParams } from '../types';

// Generic health check tools for your Opal integration
export class HealthFunctions extends ToolFunction {
  protected getClient(authData?: OptiIdAuthData): ApiClient {
    if (!authData?.credentials) {
      throw new Error(
        'API credentials are required. Please configure the app settings.'
      );
    }
    return new ApiClient(authData.credentials);
  }

  @tool({
    name: 'health_check',
    description: 'Check the health status of the configured API',
    endpoint: '/tools/health_check',
    parameters: []
  })
  async healthCheck(params: ToolParams, authData?: OptiIdAuthData) {
    const startTime = Date.now();
    try {
      const client = this.getClient(authData);

      // Call a simple endpoint (update "/health" to match your API if needed)
      const response = await client.get('/health');
      const responseTime = Date.now() - startTime;

      return {
        success: true as const,
        status: 'healthy' as const,
        message: 'API is accessible',
        responseTime: `${responseTime}ms`,
        timestamp: new Date().toISOString(),
        data: response
      };
    } catch (error: any) {
      const responseTime = Date.now() - startTime;

      const isConnectionError =
        error.code === 'ECONNREFUSED' ||
        error.code === 'ETIMEDOUT' ||
        error.message?.includes('timeout') ||
        error.message?.includes('network');

      return {
        success: false as const,
        status: (isConnectionError ? 'down' : 'error') as 'down' | 'error',
        message: isConnectionError
          ? 'API is unreachable or down'
          : `API error: ${error.message || 'Unknown error'}`,
        responseTime: `${responseTime}ms`,
        timestamp: new Date().toISOString(),
        error: {
          code: error.code || 'UNKNOWN',
          message: error.message || 'Failed to connect to API',
          status: error.response?.status,
          statusText: error.response?.statusText
        }
      };
    }
  }
}
'@ | Set-Content -Path "src\functions\HealthFunctions.ts" -Encoding UTF8

        Write-Section "Scaffolding src\functions\OpalToolFunction.ts"
        @'
// Main entry point class for your Opal tool.
// Extend HealthFunctions so the health_check tool is available immediately.
import { HealthFunctions } from './HealthFunctions';

export class OpalToolFunction extends HealthFunctions {}
'@ | Set-Content -Path "src\functions\OpalToolFunction.ts" -Encoding UTF8

        Write-Section "Configuring tsconfig.json"
        @"
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "declaration": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
"@ | Set-Content -Path "tsconfig.json" -Encoding UTF8

        Write-Section "Configuring app.yml"
        $appId = ($ProjectName -replace '\s+', '-').ToLower()
        @"
meta:
  app_id: $appId
  name: $ProjectName
  display_name: $ProjectName
  version: 1.0.0
  vendor: $Vendor
  contact_email: $ContactEmail
  support_url: $SupportUrl
  categories:
    - Opal
  availability:
    - all
runtime: node22
functions:
  opal_tool:
    opal_tool: true
    entry_point: OpalToolFunction
    description: OCP Opal tool function for third-party API integration
"@ | Set-Content -Path "app.yml" -Encoding UTF8

        Write-Section "Configuring forms/settings.yml"
        @"
fields:
  - name: apiUrl
    label: API URL
    type: text
    required: true
    placeholder: https://your-account.api.com
    description: The base URL for the API
  - name: apiKey
    label: API Key
    type: password
    required: true
    description: Your API key for authentication
"@ | Set-Content -Path "forms\settings.yml" -Encoding UTF8

        Write-Section "Configuring .eslintrc.json"
        @"
{
  "parser": "@typescript-eslint/parser",
  "extends": [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended"
  ],
  "parserOptions": {
    "ecmaVersion": 2020,
    "sourceType": "module"
  },
  "rules": {}
}
"@ | Set-Content -Path ".eslintrc.json" -Encoding UTF8

        Write-Section "Scaffolding assets/logo.svg"
        @"
<svg width="120" height="40" viewBox="0 0 120 40" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="1" y="1" width="118" height="38" rx="6" fill="#001D28"/>
  <rect x="1" y="1" width="118" height="38" rx="6" stroke="#00B3E6" stroke-width="2"/>
  <text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle"
        font-family="Segoe UI, -apple-system, BlinkMacSystemFont, sans-serif"
        font-size="14" fill="#FFFFFF">
    $ProjectName
  </text>
</svg>
"@ | Set-Content -Path "assets\logo.svg" -Encoding UTF8

        Write-Section "Scaffolding assets/directory/overview.md"
        @"
# $ProjectName

This Opal tool app integrates an external API or service into Optimizely's Opal platform.
It was scaffolded using the `Scaffold-OcpOpalTool.ps1` script.

## What this app does

- Provides a starting point for building Opal tools backed by your own API.
- Includes a generic API client, lifecycle handlers, and an initial `health_check` tool.
- Ships with a basic logo and this overview file so the app looks good in the Opal directory.

## Next steps

1. Update the app name, description, and metadata in `app.yml`.
2. Replace the logo in `assets/logo.svg` with your brand styling if desired.
3. Implement your own tool functions in `src/functions/OpalToolFunction.ts` (or new function files).
4. Extend the `ApiClient` in `src/api-client.ts` to call your real API endpoints.
5. Run `ocp dev` from this directory to test and iterate locally.

## Support

For support with this Opal tool:

- **Email**: $ContactEmail
- **Support URL**: $SupportUrl
- **Platform & API help**: Refer to the API documentation of the service this tool integrates with.
"@ | Set-Content -Path "assets\directory\overview.md" -Encoding UTF8

        # package.json already fully configured above

        Write-Section "Installing dependencies (yarn install)"
        yarn install

        # Ensure any existing yarn.lock is removed before building
        if (Test-Path "yarn.lock") {
            Remove-Item "yarn.lock" -Force
        }

        Write-Section "Building project (yarn build)"
        try {
            yarn build
        } catch {
            Write-Host "Build failed. Please inspect the errors above and fix them in your source files." -ForegroundColor Yellow
        }

        Write-Section "Validating OCP app (ocp app validate)"
        if (Command-Exists "ocp") {
            try {
                ocp app validate
                Read-Host "Press Enter to start the local development server (ocp dev)"
                ocp dev
                Read-Host "Press Enter to exit"
                
            } catch {
                Write-Host ""
                Write-Host "OCP app validation encountered errors." -ForegroundColor Yellow
                Write-Host $_.Exception.Message -ForegroundColor Red
                if ($_.ScriptStackTrace) {
                    Write-Host ""
                    Write-Host "Stack trace:" -ForegroundColor DarkGray
                    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
                }
                Write-Host ""
                Read-Host "Press Enter to start the local development server (ocp dev) despite validation errors"
                ocp dev
            }
        } else {
            Write-Host "ocp CLI not available; skipping validation. Ensure @optimizely/ocp-cli is installed and in PATH." -ForegroundColor Yellow
        }
    }
    finally {
        Pop-Location
    }
}

Write-Section "Starting OCP Opal tool setup"

try {
    Ensure-Node
    Ensure-Git
    Ensure-Ocp-Credentials
    Ensure-Ocp-Cli
    Initialize-Project

    Write-Section "Setup complete"
    Write-Host "Your OCP Opal tool app has been scaffolded in the '$ProjectName' directory."
    Write-Host "Next steps:"
    Write-Host "  - Implement your TypeScript source files in src/"
    Write-Host "  - Run 'ocp dev' inside the project directory to start local development (once ocp CLI is configured)."
}
catch {
    Write-Host "" 
    Write-Host "ERROR: OCP Opal tool setup failed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.ScriptStackTrace) {
        Write-Host ""
        Write-Host "Stack trace:" -ForegroundColor DarkGray
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    }
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

