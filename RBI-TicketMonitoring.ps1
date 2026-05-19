# ============================================================
# RBI Ticket Monitoring SOP - Automation Script
# Monitoring Window: 9:00 PM ET - 9:00 AM ET
# Check Frequency: Every 30 minutes
# Alerting: Slack Incoming Webhook
# ============================================================

#region --- CONFIGURATION ---
$Config = @{
    # Slack Webhook (Incoming Webhook URL from your Slack App)
    SlackWebhookUrl     = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
    SlackChannel        = "#team-noc-chat"   # Channel to post alerts into
    SlackBotName        = "RBI Monitor Bot"

    # RBI Ticket System API (adjust to your ticketing system)
    TicketApiBaseUrl    = "https://your-ticketing-system/api"
    TicketApiKey        = "YOUR_TICKET_API_KEY"

    # Monitoring settings
    MonitoringStartHour = 21   # 9 PM ET
    MonitoringEndHour   = 9    # 9 AM ET
    CheckIntervalMin    = 30   # Minutes between checks
    IncidentThreshold   = 5    # Tickets needed to open incident

    # Logging
    LogPath             = "C:\Logs\RBI_Monitoring"
}
#endregion

#region --- LOGGING ---
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR","SUCCESS")]
        [string]$Level = "INFO"
    )

    if (-not (Test-Path $Config.LogPath)) {
        New-Item -ItemType Directory -Path $Config.LogPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile   = Join-Path $Config.LogPath "RBI_Monitor_$(Get-Date -Format 'yyyy-MM-dd').log"
    $entry     = "[$timestamp] [$Level] $Message"

    Add-Content -Path $logFile -Value $entry
    $color = @{ INFO="Cyan"; WARN="Yellow"; ERROR="Red"; SUCCESS="Green" }[$Level]
    Write-Host $entry -ForegroundColor $color
}
#endregion

#region --- MONITORING WINDOW CHECK ---
function Test-InMonitoringWindow {
    $now  = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date), "Eastern Standard Time")
    $hour = $now.Hour

    # Window: 9 PM (21) through midnight, and midnight through 9 AM
    return ($hour -ge $Config.MonitoringStartHour -or $hour -lt $Config.MonitoringEndHour)
}
#endregion

#region --- TICKET SYSTEM INTEGRATION ---
function Get-RBITicketQueue {
    <#
    .SYNOPSIS
        Pulls open tickets from the RBI ticket queue.
        Adapt the Invoke-RestMethod call to your actual ticketing API.
    #>
    Write-Log "Fetching RBI ticket queue..."

    try {
        $headers = @{
            "Authorization" = "Bearer $($Config.TicketApiKey)"
            "Content-Type"  = "application/json"
        }

        # --- Replace with your actual ticket API endpoint and filters ---
        $response = Invoke-RestMethod `
            -Uri "$($Config.TicketApiBaseUrl)/tickets?status=open&queue=RBI" `
            -Headers $headers `
            -Method GET `
            -ErrorAction Stop

        Write-Log "Retrieved $($response.tickets.Count) open RBI tickets." "SUCCESS"
        return $response.tickets
    }
    catch {
        Write-Log "Failed to fetch ticket queue: $_" "ERROR"
        return @()
    }
}

function Find-CommonalityGroups {
    param([array]$Tickets)
    <#
    .SYNOPSIS
        Groups tickets by shared app/system to identify commonalities.
        Adjust the grouping property to match your ticket schema.
    #>
    $groups = $Tickets | Group-Object -Property { $_.affected_system }  # adjust field name

    $flagged = $groups | Where-Object { $_.Count -ge $Config.IncidentThreshold }

    foreach ($group in $flagged) {
        Write-Log "THRESHOLD MET: '$($group.Name)' has $($group.Count) tickets." "WARN"
    }

    return $flagged
}
#endregion

#region --- SLACK INTEGRATION ---
function Send-SlackAlert {
    param(
        [string]$AffectedSystem,
        [string]$IssueType,
        [array]$RelatedTickets,
        [string]$Severity = "SEV4",
        [array]$ErrorLogs = @()
    )

    Write-Log "Sending Slack alert for: $AffectedSystem ($Severity)"

    $timestamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $ticketList = ($RelatedTickets | ForEach-Object { "• Ticket #$($_.id): $($_.title)" }) -join "`n"
    $logSummary = if ($ErrorLogs.Count -gt 0) { $ErrorLogs -join ", " } else { "None captured at this time." }

    # Slack Block Kit message for rich formatting
    $payload = @{
        username = $Config.SlackBotName
        channel  = $Config.SlackChannel
        blocks   = @(
            @{
                type = "header"
                text = @{ type = "plain_text"; text = ":rotating_light: RBI Incident Alert - $Severity" }
            },
            @{
                type   = "section"
                fields = @(
                    @{ type = "mrkdwn"; text = "*Affected System:*`n$AffectedSystem" },
                    @{ type = "mrkdwn"; text = "*Issue Type:*`n$IssueType" },
                    @{ type = "mrkdwn"; text = "*Severity:*`n$Severity" },
                    @{ type = "mrkdwn"; text = "*Ticket Count:*`n$($RelatedTickets.Count)" },
                    @{ type = "mrkdwn"; text = "*Triggered At:*`n$timestamp ET" }
                )
            },
            @{
                type = "divider"
            },
            @{
                type = "section"
                text = @{ type = "mrkdwn"; text = "*Related Tickets:*`n$ticketList" }
            },
            @{
                type = "section"
                text = @{ type = "mrkdwn"; text = "*Error Logs:*`n$logSummary" }
            },
            @{
                type = "divider"
            },
            @{
                type = "section"
                text = @{
                    type = "mrkdwn"
                    text = "*:clipboard: Action Required:*`n1. Review all related tickets above.`n2. Notify on-call engineers/App owners immediately.`n3. Provide any relevant error messages or system logs.`n4. Open a TI if needed for the specific affected item."
                }
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        Invoke-RestMethod `
            -Uri         $Config.SlackWebhookUrl `
            -Method      POST `
            -Body        $payload `
            -ContentType "application/json" `
            -ErrorAction Stop

        Write-Log "Slack alert sent to $($Config.SlackChannel) for $AffectedSystem." "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to send Slack alert: $_" "ERROR"
        return $false
    }
}
#endregion

#region --- INCIDENT TRACKING (avoid duplicate alerts) ---
$script:OpenIncidents = @{}   # Key: AffectedSystem, Value: timestamp of first alert

function Invoke-EscalationCheck {
    param([array]$FlaggedGroups)

    foreach ($group in $FlaggedGroups) {
        $system  = $group.Name
        $tickets = $group.Group

        if ($script:OpenIncidents.ContainsKey($system)) {
            Write-Log "Alert already sent for '$system' (first alerted: $($script:OpenIncidents[$system])). Skipping." "INFO"
            continue
        }

        # Determine issue type from ticket data (adjust field to your schema)
        $issueType = ($tickets | Group-Object -Property { $_.issue_category } |
                      Sort-Object Count -Descending | Select-Object -First 1).Name

        $sent = Send-SlackAlert `
            -AffectedSystem $system `
            -IssueType      ($issueType ?? "Unknown") `
            -RelatedTickets $tickets `
            -Severity       "SEV4"

        if ($sent) {
            $script:OpenIncidents[$system] = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
    }
}
#endregion

#region --- MAIN MONITORING LOOP ---
function Start-RBIMonitoring {
    Write-Log "============================================" "INFO"
    Write-Log " RBI Ticket Monitoring Automation Started  " "INFO"
    Write-Log "============================================" "INFO"

    while ($true) {

        if (-not (Test-InMonitoringWindow)) {
            $nextCheck = Get-Date -Format "HH:mm:ss"
            Write-Log "Outside monitoring window (9 PM - 9 AM ET). Sleeping 15 min... [$nextCheck]"
            Start-Sleep -Seconds 900
            continue
        }

        Write-Log "--- Monitoring check started ---"

        # Step 1: Fetch RBI ticket queue
        $tickets = Get-RBITicketQueue

        if ($tickets.Count -eq 0) {
            Write-Log "No open tickets found in RBI queue."
        }
        else {
            # Step 2: Find tickets with commonalities (same app/system)
            $flaggedGroups = Find-CommonalityGroups -Tickets $tickets

            if ($flaggedGroups.Count -eq 0) {
                Write-Log "No groups have reached the incident threshold ($($Config.IncidentThreshold) tickets)."
            }
            else {
                # Step 3: Escalate - open incident, page engineers, document
                Invoke-EscalationCheck -FlaggedGroups $flaggedGroups
            }
        }

        Write-Log "--- Check complete. Next check in $($Config.CheckIntervalMin) minutes ---"
        Start-Sleep -Seconds ($Config.CheckIntervalMin * 60)
    }
}
#endregion

# ============================================================
# ENTRY POINT
# Run as a scheduled task or directly in a PowerShell session.
# To run: .\RBI-TicketMonitoring.ps1
# ============================================================
Start-RBIMonitoring
