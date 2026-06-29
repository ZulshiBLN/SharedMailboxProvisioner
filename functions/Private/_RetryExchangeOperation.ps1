<#
.SYNOPSIS
Execute Exchange Online operation with automatic retry & exponential backoff

.DESCRIPTION
Wraps ScriptBlock execution with resilience pattern for Exchange Online API calls.
Handles transient errors (throttling, timeouts) with exponential backoff retry.
Classifies errors into retryable vs permanent for intelligent retry logic.

Per ADR-003: Error Handling & Robustness
#>

function _RetryExchangeOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$InitialBackoffMs = 100,

        [Parameter(Mandatory = $false)]
        [string]$OperationName = "Exchange Operation"
    )

    if (-not $ScriptBlock) {
        Write-Error "ScriptBlock parameter required"
        return $null
    }

    $attempt = 0
    $lastException = $null

    while ($attempt -lt $MaxRetries) {
        try {
            $attempt++
            Write-Verbose "[Retry] Attempt $attempt of $MaxRetries - $OperationName"

            $result = & $ScriptBlock
            return $result

        } catch {
            $lastException = $_
            $errorMessage = $_.Exception.Message
            $errorType = $_.Exception.GetType().Name

            # Classify error: is it retryable?
            $isRetryable = _IsRetryableError -Exception $_ -ErrorMessage $errorMessage

            if (-not $isRetryable -or $attempt -ge $MaxRetries) {
                # Permanent error or max retries reached
                Write-Error "[$OperationName] Permanent error (retryable: $isRetryable, attempts: $attempt/$MaxRetries): $errorMessage"
                throw $_
            }

            # Calculate exponential backoff with jitter
            $backoffMs = $InitialBackoffMs * [Math]::Pow(2, $attempt - 1)
            $jitterMs = Get-Random -Minimum 0 -Maximum [int]($backoffMs * 0.1)
            $totalWait = $backoffMs + $jitterMs

            Write-Verbose "[$OperationName] Retryable error. Waiting ${totalWait}ms before retry attempt $($attempt + 1) of $MaxRetries"
            Write-Verbose "  Error: $errorMessage"

            Start-Sleep -Milliseconds $totalWait
        }
    }

    # Should not reach here, but failsafe
    Write-Error "[$OperationName] Failed after $MaxRetries attempts"
    throw $lastException
}

function _IsRetryableError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Exception,

        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage = ""
    )

    if (-not $Exception) {
        return $false
    }

    $exceptionMessage = $Exception.Exception.Message
    $exceptionType = $Exception.Exception.GetType().Name

    # Retryable patterns
    $retryablePatterns = @(
        'Throttling'                    # Microsoft throttling (429)
        'Throttled'
        'TooManyRequests'
        'Service Unavailable'           # 503
        'ServiceUnavailable'
        'Timeout'                       # Request timeout
        'TimeoutException'
        'The operation timed out'
        'temporarily unavailable'       # Transient service issue
        'temporarily unavailable'
        'transient error'
        'Connection reset'
        'connection was closed'
        'broken pipe'
        'Connection timeout'
        'ECONNRESET'                    # Network errors
        'ECONNREFUSED'
        'ENETUNREACH'
    )

    foreach ($pattern in $retryablePatterns) {
        if ($exceptionMessage -match $pattern -or $exceptionType -match $pattern) {
            return $true
        }
    }

    # Check for HTTP status codes in error messages
    if ($exceptionMessage -match '(429|503|504|408)') {
        return $true
    }

    # Permanent errors (not retryable)
    $permanentPatterns = @(
        'Access Denied'                 # 403
        'Unauthorized'
        'Invalid'                       # Bad request (400)
        'not found'                     # 404
        'does not exist'
        'NotFound'
        'BadRequest'
        'Forbidden'
        'permission'
        'not authorized'
    )

    foreach ($pattern in $permanentPatterns) {
        if ($exceptionMessage -match $pattern) {
            return $false
        }
    }

    # Default: unknown errors are not retried (safe default)
    return $false
}

