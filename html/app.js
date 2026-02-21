// ======================
// GLOBAL VARIABLES
// ======================
let currentJobId = null;
let playerLevel = 1;
let currentConvoyID = null;
let isLeader = false;
let myServerID = null; 
let jobList = [];

// ======================
// INITIAL SETUP
// ======================
$(document).ready(function () {
    $('html, body').hide();

    // Close button listener
    $('.close, #closeBtn, .close-button').click(function() {
        closeMenu();
    });

    $('.nav-item').click(function() {
        const targetPage = $(this).data('page');
        $('.nav-item').removeClass('active');
        $(this).addClass('active');

        $('.page-container').hide(); 
        $(`#${targetPage}`).fadeIn(200);
    });

    $('#sendInviteBtn').click(function() {
        const targetID = $('#invitePlayerID').val();
        if (targetID) {
            $.post(`https://${GetParentResourceName()}/invitePlayer`, JSON.stringify({ id: targetID }));
            $('#invitePlayerID').val('');
        }
    });

    $('#cancel').click(() => { $('.popUp').fadeOut(200); });
    
    $('#confirm').click(function () {
        if (!currentJobId) return;
        const selectedJob = jobList.find(j => j.id === currentJobId);
        if (!selectedJob) return;

        $.post(`https://${GetParentResourceName()}/startJob`, JSON.stringify({
            jobId: selectedJob.id,
            jobType: selectedJob.type,
            convoyID: currentConvoyID 
        }));

        $('.popUp').fadeOut(200);
        closeMenu();
    });
});

// ======================
// NUI MESSAGE LISTENER
// ======================
window.addEventListener('message', function (event) {
    const data = event.data;

    switch (data.type || data.action) {
        case "openUI":
            myServerID = data.serverID;
            jobList = data.jobs || [];
            if (data.player) {
                $('#playerName').text(data.player.name);
                updateLevelUI(data.player.xp, data.player.level);
            }
            loadJobs();
            $('html, body').fadeIn(200);
            break;

        case "close":
            $('html, body').fadeOut(200);
            break;

        case "updateConvoy":
        case "updateConvoyPlayers":
            currentConvoyID = data.convoyID || currentConvoyID;
            const members = data.members || data.players || [];
            const me = members.find(m => m.id === myServerID);
            
            // Check leader status
            isLeader = me && (me.isLeader || (me.name && me.name.includes("(Leader)")));

            if (currentConvoyID) {
                $('#convoyAuth').hide();
                $('#convoyLobby').fadeIn(300);
                $('#activeConvoyID').text("#" + currentConvoyID);
                renderLobbyPlayers(members);
            }
            loadJobs(); 
            break;

        case "syncJob":
        case "syncMission":
            const jobData = data.jobData || data.job;
            if (jobData) {
                currentJobId = jobData.id;
                updateLobbyMission(jobData);
                loadJobs(); // Refresh active state in list
            }
            break;

        case "resetConvoy":
            resetConvoyUI();
            break;
            
        case "updateStats":
            if (data.updateStats) {
                updateLevelUI(data.updateStats.xp, data.updateStats.level);
                loadJobs();
            }
            break;
    }
});

// ======================
// CONVOY SYSTEM ACTIONS
// ======================

$('#createConvoyBtn').click(function() {
    const randomID = Math.floor(1000 + Math.random() * 9000);
    $.post(`https://${GetParentResourceName()}/createConvoy`, JSON.stringify({ convoyID: randomID }));
});

$('#joinConvoyBtn').click(function() {
    const id = $('#joinIDInput').val();
    if (id) $.post(`https://${GetParentResourceName()}/joinConvoy`, JSON.stringify({ convoyID: id }));
});

$('#leaveConvoyBtn').click(function() {
    $.post(`https://${GetParentResourceName()}/leaveConvoy`, JSON.stringify({}));
    resetConvoyUI();
});

function resetConvoyUI() {
    currentConvoyID = null;
    isLeader = false;
    currentJobId = null;
    $('#convoyLobby').hide();
    $('#convoyAuth').fadeIn(300);
    updateLobbyMission(null);
    loadJobs();
}

function renderLobbyPlayers(players) {
    const container = $('#playerList');
    container.empty();
    if (!players) return;
    
    players.forEach(player => {
        container.append(`
            <div class="player-row">
                <span><i class="fa-solid fa-user-check" style="color:var(--accent)"></i> ${player.name}</span>
                <span style="opacity:0.5; font-size: 0.7vw;">ID: ${player.id}</span>
            </div>
        `.trim());
    });
}

// ======================
// UI RENDERING
// ======================
function loadJobs() {
    const container = $('.listArea');
    container.empty();

    // Show lock overlay if in convoy and not leader
    if (currentConvoyID && !isLeader) {
        container.append(`
            <div class="job-lock-overlay">
                <i class="fa-solid fa-lock" style="font-size: 3vw; color: var(--accent); margin-bottom: 15px;"></i>
                <span>WAITING FOR LEADER TO PICK MISSION...</span>
            </div>
        `.trim());
    }

    jobList.forEach(job => {
        const levelLocked = playerLevel < job.level;
        const activeClass = (currentJobId === job.id) ? 'active' : '';

        const itemHtml = `
            <div class="trailerItem ${levelLocked ? 'locked' : ''} ${activeClass}" data-id="${job.id}">
                ${levelLocked ? `<div class="locked-overlay"><i class="fa-solid fa-lock"></i> Level ${job.level}</div>` : ''}
                <div class="trailerImg"><img src="${job.imgSrc}"></div>
                <div class="trailerInfo">
                    <div class="trailerName">${job.name}</div>
                    <div class="trailerPrice">$${job.totalPrice}</div>
                </div>
            </div>
        `.trim();

        const item = $(itemHtml);

        item.click(function() {
            // Prevent selection if locked or if member in a convoy
            if (levelLocked || (currentConvoyID && !isLeader)) return;
            
            currentJobId = job.id;
            $('.trailerItem').removeClass('active');
            $(this).addClass('active');

            // Sync choice with server for convoy members
            $.post(`https://${GetParentResourceName()}/selectJob`, JSON.stringify({
                convoyID: currentConvoyID,
                jobData: job
            }));

            $('.popUpText').html(`Start delivery: <span style="color:var(--accent)">${job.name}</span>?`);
            $('.popUp').fadeIn(200);
        });

        container.append(item);
    });
}

function updateLevelUI(currentXP, level) {
    playerLevel = level;
    $('.levelStatus').css('width', `${(currentXP / 100) * 100}%`);
    $('.levelText').text(`Level ${playerLevel} — ${currentXP}/100 XP`);
}

function updateLobbyMission(job) {
    const container = $('#lobbyMissionInfo');
    if (!container.length) return;
    
    if (!job) {
        container.css('opacity', '0.5').html('<i>No mission selected</i>');
        return;
    }

    container.css('opacity', '1').html(`
        <div style="display:flex; align-items:center; gap:15px; width:100%;">
            <img src="${job.imgSrc}" style="width: 5vw; border-radius: 5px;">
            <div>
                <div style="color:var(--accent); font-weight:bold;">${job.name}</div>
                <div style="font-size:0.8vw;">Payout: $${job.totalPrice}</div>
            </div>
        </div>
    `.trim());
}

function closeMenu() {
    $('html, body').fadeOut(200);
    $.post(`https://${GetParentResourceName()}/closeUI`, JSON.stringify({}));
}
