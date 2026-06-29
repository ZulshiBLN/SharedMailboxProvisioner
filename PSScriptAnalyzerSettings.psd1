@{
    Severity = @('Error', 'Warning')

    IncludeRules = @(
        'PSAvoidDefaultValueSwitchParameter',
        'PSAvoidGlobalAliases',
        'PSAvoidGlobalFunctions',
        'PSAvoidGlobalVariables',
        'PSAvoidInvokeExpression',
        'PSAvoidNullCheckedForceCmdletBinding',
        'PSAvoidUsingBrokenHashtables',
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingComputerNameHardcoded',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingDeprecatedManifestFields',
        'PSAvoidUsingDoubleQuotedStrings',
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingPositionalParameters',
        'PSAvoidUsingWriteHost',
        'PSMissingModuleManifestField',
        'PSPossibleIncorrectComparisonWithNull',
        'PSPossibleIncorrectUsageOfRedirectionOperator',
        'PSPossibleIncorrectUsageOfComparisonOperators',
        'PSProvideCommentHelp',
        'PSReviewUnusedParameter',
        'PSUseApprovedVerbs',
        'PSUseConsistentIndentation',
        'PSUseConsistentWhitespace',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUseOutputTypeCorrectly',
        'PSUsePSCredentialType',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseToExportFieldsInManifest',
        'PSUseUTF8EncodingForHelpFile'
    )

    ExcludeRules = @(
        'PSAvoidUsingDoubleQuotedStrings'
    )

    Rules = @{
        PSAvoidInvokeExpression = @{
            Enable = $true
        }

        PSAvoidUsingWriteHost = @{
            Enable = $true
        }

        PSAvoidUsingPlainTextForPassword = @{
            Enable = $true
        }

        PSProvideCommentHelp = @{
            Enable = $true
            ExportedOnly = $true
            BlockComment = $false
        }

        PSUseConsistentIndentation = @{
            Enable = $true
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }

        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipeForRedundantWhitespace = $false
            CheckSeparator = $true
        }

        PSUseApprovedVerbs = @{
            Enable = $true
        }
    }
}
