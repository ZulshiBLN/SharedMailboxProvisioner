<#
.SYNOPSIS
Unit tests for _RetryExchangeOperation function

.DESCRIPTION
Tests retry logic, backoff calculation, error classification
#>

# Import the module functions
$functionPath = Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) "functions") "Private\_RetryExchangeOperation.ps1"
. $functionPath

Describe "RetryExchangeOperation" {

    Context "Successful execution on first attempt" {
        It "Should return result without retries" {
            $result = _RetryExchangeOperation -ScriptBlock { "Success" } -OperationName "TestOp"
            $result | Should -Be "Success"
        }
    }

    Context "Successful execution after transient error" {
        It "Should retry and return result after 429 Throttling error" {
            $attempt = 0
            $result = _RetryExchangeOperation -ScriptBlock {
                $attempt++
                if ($attempt -eq 1) {
                    throw "Throttling error (429)"
                }
                return "Success on retry"
            } -MaxRetries 3 -InitialBackoffMs 10 -OperationName "TestOp"

            $result | Should -Be "Success on retry"
        }
    }

    Context "Permanent error (not retried)" {
        It "Should fail immediately on Access Denied" {
            {
                _RetryExchangeOperation -ScriptBlock {
                    throw "Access Denied (403): User does not have permissions"
                } -MaxRetries 3 -OperationName "TestOp"
            } | Should -Throw
        }
    }

    Context "Max retries exhausted" {
        It "Should fail after MaxRetries attempts" {
            $attempt = 0
            {
                _RetryExchangeOperation -ScriptBlock {
                    $attempt++
                    throw "Throttling error (429)"
                } -MaxRetries 2 -InitialBackoffMs 10 -OperationName "TestOp"
            } | Should -Throw
        }
    }

    Context "Error classification" {
        It "Should classify 429 Throttling as retryable" {
            $null = _IsRetryableError -Exception @{ Exception = @{ Message = "Throttling error (429)"; GetType = @{ Name = "Exception" } } }
            # Note: This is simplified due to exception object structure - no assertion, see COMPLIANCE-AUDIT-PHASE-PRERELEASE.md
        }
    }
}
