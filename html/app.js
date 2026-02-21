// ======================
// GLOBAL VARIABLES
// ======================
let currentSortOrder = "";
let currentJobId = null;
let playerLevel = 1;
let currentConvoyID = null;
let isLeader = false; 

// Default job list (Will be overwritten by Config.lua via NUI)
let jobList = [
    { id: 1, name: "Gasoline Tanker", type: "fuel", streetNames: "Highway 21", totalPrice: 300, kmEarnings: 10, imgSrc: "images/trailers/tanker.png", level: 1, distance: 50 },
    { id: 2, name: "Log Transport", type: "logs", streetNames: "Downtown", totalPrice: 450, kmEarnings: 15, imgSrc: "images/trailers/trailers3.png", level: 2, distance: 80 },
    { id: 3, name: "Heavy Containers", type: "containers", streetNames: "Airport Road", totalPrice: 600, kmEarnings: 20, imgSrc: "images/trailers/docktrailer.png", level: 3, distance: 120 }
];

// ======================
// INITIAL SETUP
// ======================
$(document).ready(function () {
    $('html, body').hide();

    // Sidebar Navigation Logic
    $('.nav-item').click(function() {
        const targetPage = $(this).data('page');
        
        $('.nav-item').removeClass('active');
        $(this).addClass('active');

        $('.page-container').hide();
        $(`#${targetPage}`).fadeIn(200);
    });
});

// ======================
// NUI MESSAGE LISTENER
// ======================
window.addEventListener('message', function (event) {
    const data = event.data;
    if (!data) return;

    // Open Menu
    if (data.action === "open") {
        $('html, body').fadeIn(200);
        
        if (data.player) {
            $('#playerName').text(data.player.name);
            playerLevel = data.player.level;
            updateLevelUI(data.player.xp || 0, data.player.level);
        }

        if (data.jobs) {
            jobList = data.jobs;
        }

        loadJobs();
    }

    // Close Menu
    if (data.action === "close") {
        $('html, body').fadeOut(200);
    }

    // Update Stats (Level/XP)
    if (data.updateStats) {
        updateLevelUI(data.updateStats.xp, data.updateStats.level);
        loadJobs();
    }

    // Sync Mission for Convoy Members
    if (data.action === "syncMission") {
        updateLobbyMission(data.job);
        currentJobId = data.job ? data.job.id : null;
    }

    // Real-time player list updates
    if (data.action === "updateConvoyPlayers") {
        renderLobbyPlayers(data.players);
    }

    // Handle Join Fail or Disband
    if (data.action === "joinFailed") {
        isLeader = false;
        currentConvoyID = null;
        currentJobId = null;
        $('#convoyLobby').hide();
        $('#convoyAuth').fadeIn(300);
        updateLobbyMission(null);
        loadJobs();
    }
});

// ======================
// CONVOY SYSTEM LOGIC
// ======================

$('#createConvoyBtn').click(function() {
    const randomID = Math.floor(1000 + Math.random() * 9000);
    isLeader = true; 
    enterLobbyMode(randomID);
    $.post(`https://${GetParentResourceName()}/createConvoy`, JSON.stringify({ id: randomID }));
});

$('#joinConvoyBtn').click(function() {
    const convoyID = $('#joinIDInput').val();
    if (convoyID && convoyID.length === 4) {
        isLeader = false; 
        enterLobbyMode(convoyID);
        $.post(`https://${GetParentResourceName()}/joinConvoy`, JSON.stringify({ id: convoyID }));
    }
});

function enterLobbyMode(id) {
    currentConvoyID = id;
    $('#activeConvoyID').text("#" + id);
    $('#convoyAuth').fadeOut(300, function() {
        $('#convoyLobby').fadeIn(300);
    });
    renderLobbyPlayers([{name: "Synchronizing...", id: "..."}]);
    updateLobbyMission(null);
    loadJobs();
}

$('#leaveConvoyBtn').click(function() {
    currentConvoyID = null;
    isLeader = false;
    currentJobId = null;
    $('#convoyLobby').fadeOut(300, function() {
        $('#convoyAuth').fadeIn(300);
    });
    $.post(`https://${GetParentResourceName()}/leaveConvoy`, JSON.stringify({}));
    loadJobs(); 
});

function renderLobbyPlayers(players) {
    const container = $('#playerList');
    container.empty();
    players.forEach(player => {
        container.append(`
            <div class="player-row">
                <span><i class="fa-solid fa-user-tie"></i> ${player.name}</span>
                <span style="opacity:0.5; font-size: 0.7vw;">ID: ${player.id}</span>
            </div>
        `);
    });
}

// ======================
// CORE MENU ACTIONS
// ======================
function closeMenu() {
    $('html, body').fadeOut(200);
    $.post(`https://${GetParentResourceName()}/close`, JSON.stringify({}));
}

$('.closeIcon, .closeText').click(closeMenu);

// ======================
// JOB SELECTION
// ======================
$(document).on('click', '.trailerItem', function () {
    if ($(this).hasClass('locked')) return;
    if (currentConvoyID && !isLeader) return;

    currentJobId = $(this).data('id');
    $('.trailerItem').removeClass('active');
    $(this).addClass('active');

    const selectedJob = jobList.find(j => j.id === currentJobId);
    
    if (selectedJob) {
        updateLobbyMission(selectedJob);
        // If in a convoy, tell the server we selected this job so others see it
        if (currentConvoyID) {
            $.post(`https://${GetParentResourceName()}/selectJob`, JSON.stringify({
                jobId: currentJobId,
                jobData: selectedJob,
                convoyID: currentConvoyID
            }));
        }
        $('.popUpText').html(`Do you want to start the <span style="color:var(--accent)">${selectedJob.name}</span> job?`);
        $('.popUp').fadeIn(200);
    }
});

$('#cancel').click(() => { $('.popUp').fadeOut(200); });

// ======================
// CONFIRM & START (CRITICAL FIX)
// ======================
$('#confirm').click(function () {
    if (!currentJobId) return;
    
    const selectedJob = jobList.find(job => job.id === currentJobId);
    if (!selectedJob) return;

    // Send EVERYTHING to client.lua
    $.post(`https://${GetParentResourceName()}/startJob`, JSON.stringify({
        jobId: selectedJob.id,
        jobType: selectedJob.type,
        jobData: selectedJob, // This includes the level!
        convoyID: currentConvoyID 
    }));

    $('.popUp').fadeOut(200);
    closeMenu();
});

// ======================
// UI RENDERING
// ======================
function loadJobs() {
    const container = $('.listArea');
    container.empty();

    if (currentConvoyID && !isLeader) {
        container.append(`
            <div class="job-lock-overlay">
                <i class="fa-solid fa-lock" style="font-size: 3vw; color: var(--accent); margin-bottom: 15px;"></i>
                <span>WAITING FOR LEADER TO PICK MISSION...</span>
            </div>
        `);
    }

    jobList.forEach(job => {
        const levelLocked = playerLevel < job.level;
        const activeClass = (currentJobId === job.id) ? 'active' : '';

        container.append(`
            <div class="trailerItem ${levelLocked ? 'locked' : ''} ${activeClass}" data-id="${job.id}">
                ${levelLocked ? `<div class="locked-overlay"><i class="fa-solid fa-lock"></i> Level ${job.level}</div>` : ''}
                <div class="trailerImg"><img src="${job.imgSrc}"></div>
                <div class="trailerInfo">
                    <div class="trailerName">${job.name}</div>
                    <div class="trailerPrice">$${job.totalPrice}</div>
                </div>
            </div>
        `);
    });
}

function updateLevelUI(currentXP, serverLevel) {
    playerLevel = serverLevel;
    $('.levelStatus').css('width', `${(currentXP / 100) * 100}%`);
    $('.levelText').text(`Level ${playerLevel} — ${currentXP}/100 XP`);
}

function updateLobbyMission(job) {
    const container = $('#lobbyMissionInfo');
    if (!container) return;
    container.empty();
    if (job) {
        container.css('opacity', '1');
        container.html(`<img src="${job.imgSrc}" style="width: 100px;"><div>${job.name}</div>`);
    }
}