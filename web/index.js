inQueue = false;
isInContract = false;
ContractStatus = {};
Contracts = [];
playerData = {};

// console.debug = function() {
//     return false;
// };

window.addEventListener('load', () => {
    // Listen for messages (as in the original code)
    window.addEventListener('message', async({ data }) => {
        data = data.data;
        // console.debug('[TABLET Boosting App Received message]', data);
        if (data.action == 'refreshContracts') {
            if ((typeof(Contracts) != 'undefined') && (Contracts.length != data.Contracts.length)) {
                window.parent.triggerNotification({ title: 'Nuevo contrato de Boosting', text: 'Acabas de recibir un nuevo contrato!', icon: 'info', timer: 3400, sound: 'notification3' });
            };
            Contracts = data.Contracts;
            contractDiv = document.getElementsByClassName('dashboard-main')[0].innerHTML = '';
            for (let index = 0; index < data.Contracts.length; index++) {
                if (ContractStatus[data.Contracts[index].contractId] == true) {
                    console.debug("Not showing this contract", data.Contracts[index].contractId, " on refreshContracts because it is probably active/accepted.")
                } else {
                    hacks = 'NO';
                    if (data.Contracts[index].hacksRequired > 0) {
                        hacks = 'SI';
                    };
                    createBoostingContract({
                        id: index,
                        imgSrc: data.Contracts[index].imgSrc,
                        vehicle: data.Contracts[index].carName,
                        // expireTime: data.Contracts[index].expire,
                        contractId: data.Contracts[index].contractId,
                        contractClass: data.Contracts[index].class,
                        contractCost: data.Contracts[index].contractCost,
                        money: data.Contracts[index].moneyReward,
                        credits: data.Contracts[index].creditReward,
                        rep: data.Contracts[index].repReward,
                        hacks: hacks
                    });
                };
            };
        } else if (data.action == 'receivePlayerData') {
            updateProfileData(data.playerData);
            playerData = data.playerData;
        } else if (data.action == 'destroyLobby') {
            console.debug('Received event to destroyLobby, destroyingLobby')
            destroyLobby();
        } else if (data.action == 'updateLobby') {
            updateLobby(data.lobby);
        } else if (data.action == 'lobbyMessage') {
            console.debug('Received lobby rejection/accept reason!')
            if (data.message == 'joined') {
                window.parent.triggerNotification({ title: 'Conexión con la casa de Blako', text: 'Te has unido a la sala!', icon: 'success', timer: 2000 });
                isInContract = true;
                showLobbyButtons(false);
            } else if (data.message == 'own') {
                isInContract = false;
                window.parent.triggerNotification({ title: 'Conexión con la casa de Blako', text: 'No puedes unirte a tu propia sala! Que estabas intentando?', icon: 'error', timer: 2000 });
            } else if (data.message == 'full') {
                isInContract = false;
                window.parent.triggerNotification({ title: 'Conexión con la casa de Blako', text: 'No puedes unirte a una sala que está llena!', icon: 'error', timer: 2000 });
                document.getElementById("joinLobby").disabled = false;
            } else if (data.message == 'started') {
                isInContract = false;
                window.parent.triggerNotification({ title: 'Conexión con la casa de Blako', text: 'No puedes unirte a una sala que ya empezó!', icon: 'error', timer: 2000 });
                document.getElementById("joinLobby").disabled = false;
            } else if (data.message == 'notexist') {
                isInContract = false;
                window.parent.triggerNotification({ title: 'Conexión con la casa de Blako', text: 'No puedes unirte a una sala que no existe!', icon: 'error', timer: 2000 });
                document.getElementById("joinLobby").disabled = false;
            } else if (data.message == 'notlevel') {
                isInContract = false;
                window.parent.triggerNotification({ title: 'Conexión con la casa de Blako', text: 'No tienes suficiente nivel para este contrato!', icon: 'error', timer: 2000 });
                document.getElementById("joinLobby").disabled = false;
            }
        } else if (data.leaderboard) {
            createLeaderboard(data.leaderboard);
        } else if (data.shopData) {
            createShop(data.shopData);
        }
    });
});

function updateProfileData(profileData) {
    // Boosting Dashboard
    document.getElementById("username").innerHTML = profileData.profile_name;
    document.getElementById("profile-picture").src = profileData.profile_picture;
    document.getElementById("reputation").innerHTML = profileData.reputation;
    document.getElementById("credits").innerHTML = profileData.credits;
    document.getElementById("current-class").innerHTML = 'Clase ' + profileData.class;
    let currentLevel = profileData.xp / profileData.xpPerLevel;
    let currentPercentage = Math.floor((currentLevel - Math.floor(currentLevel)) * 100);
    document.getElementById("level").innerHTML = Math.floor(currentLevel);
    const progressBar = document.querySelector('.ldBar');
    progressBar.ldBar.set(currentPercentage);
    // Settings Dashboard
    document.getElementById('usernameInput').placeholder = profileData.profile_name;
    document.getElementById('profilePicInput').placeholder = profileData.profile_picture;
    document.getElementById('profile-picture-settings').src = profileData.profile_picture;
    // Shop Dashboard
    let username = document.getElementById("username").innerHTML;
    let credit = document.getElementById('credits').innerHTML;
    document.getElementById("user-shop-data").innerHTML = "Buenas " + username + ", dispones actualmente de <b>" + credit + "</b> créditos.";
};

function destroyLobby() {
    document.getElementsByClassName("lobby")[0].style.visibility = "hidden";
    let currentContractId = document.getElementById("current-boosting-id").innerHTML;
    document.getElementById("current-boosting-id").innerHTML = '';
    document.getElementById("current-boosting-class").innerHTML = '';
    document.getElementById("current-boosting-money").innerHTML = '';
    document.getElementById("current-boosting-reputation").innerHTML = '';
    document.getElementById("current-boosting-credits").innerHTML = '';
    document.getElementById("current-boosting-hacks").innerHTML = '';
    document.getElementById("joinLobby").disabled = false;
    for (let index = 0; index < 3; index++) {
        document.getElementById('boosting-member-' + index).innerHTML = '';
    }
    isInContract = false;
}

function updateLobby(lobbyInfo) {
    document.getElementsByClassName("lobby")[0].style.visibility = "visible";
    document.getElementById("current-boosting-id").innerHTML = lobbyInfo.contractData.contractId;
    document.getElementById("current-boosting-class").innerHTML = lobbyInfo.contractData.class;
    document.getElementById("current-boosting-money").innerHTML = lobbyInfo.contractData.moneyReward;
    document.getElementById("current-boosting-reputation").innerHTML = lobbyInfo.contractData.repReward;
    document.getElementById("current-boosting-credits").innerHTML = lobbyInfo.contractData.creditReward;
    let hacks = 'NO';
    if (lobbyInfo.contractData.hacksRequired > 0) { hacks = 'SI' };
    document.getElementById("current-boosting-hacks").innerHTML = hacks;
    for (let index = 0; index < lobbyInfo.members.length; index++) {
        document.getElementById('boosting-member-' + index).innerHTML = lobbyInfo.members[index].playerName;
    };
};

function toggleQueue() {
    if (inQueue == true) {
        inQueue = false;
        document.getElementById('boost-status').innerHTML = 'En cola: <span style="color:red;">Inactivo</span>';
    } else {
        inQueue = true;
        document.getElementById('boost-status').innerHTML = 'En cola: <span style="color:lightgreen;">Activo</span>';
    };
    fetch(`https://joni_boosting/queueStatus`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ 'inQueue': inQueue })
    });
};

function fetchContract(id) {
    return Contracts[id];
};

function alreadyInContract() {
    return isInContract;
};

function rejectContract(id) {
    console.debug("Rejecting contract", id);
    let contractId = document.getElementById('boosting-contract-' + id + '-reject').dataset.contractId;
    document.getElementById('boosting-contract-' + id).remove();
    destroyContract(contractId);
};

function destroyContract(contractId) {
    fetch(`https://joni_boosting/destroyContract`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ 'contractId': contractId })

    });
};

// Additional check in client to avoid deleting contract from server-side if negative balance.
function checkCreditClient(contractCost) {
    if (playerData.credits >= contractCost) {
        return true
    }
    return false
}

async function acceptContract(id) {
    if (!alreadyInContract()) {
        let contract = fetchContract(id);
        let creditCheck = checkCreditClient(contract.contractCost);
        if (creditCheck) {
            let response = await fetch(`https://joni_boosting/fetchPoliceCount`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ 'class': Contracts[id].class })
            });
            policeData = await response.json();
            if (policeData['policeCount'] >= policeData['policeNeeded']) {
                window.parent.triggerNotification({ title: 'Respuesta de NAVSTAR', text: 'Contrato aprobado!', icon: 'success', timer: 3400, sound: 'success' });
                document.getElementsByClassName("lobby")[0].style.visibility = "hidden";
                document.getElementById("joinLobby").disabled = true;
                document.getElementById("joinLobby").disabled = true;
                console.debug("Accepting contract", id);
                isInContract = true;
                document.getElementById('boosting-contract-' + id).remove();
                ContractStatus[Contracts[id].contractId] = true;
                console.debug("Telling NUI to do not show contract with ID", Contracts[id].contractId);
                prepareDataLobby(contract);
                return;
            } else {
                window.parent.triggerNotification({ title: 'Respuesta de NAVSTAR', text: 'Contrato denegado!', icon: 'error', timer: 3400, sound: 'error' });
            };
        } else {
            window.parent.triggerNotification({ title: 'Respuesta de NAVSTAR', text: 'No tienes fondos para aceptar este contrato!', icon: 'error', timer: 3400, sound: 'error' });
        };
    };
    console.debug("Client is trying to accept a contract while inside another!", Contracts[id].contractId);
};

function startContract() {
    // tell to client & server that the client has started the contract to give him events.
    let contractId = document.getElementById('current-boosting-id').innerHTML;
    document.getElementById('start-contract').disabled = true;
    fetch(`https://joni_boosting/contractStarted`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ 'contractId': contractId })
    });
};

function cancelContract(buttonClicked) {
    isInContract = false;
    // document.getElementsByClassName("lobby")[0].style.visibility = "hidden";
    let currentContractId = document.getElementById("current-boosting-id").innerHTML;
    destroyContract(currentContractId);
};

function endContract() {
    isInContract = false;
};

function prepareDataLobby(contractData) {
    // Set Lobby Details (NUI)
    showLobbyButtons(true);
    let playerName = document.getElementById("username").innerHTML;
    document.getElementsByClassName("lobby")[0].style.visibility = "visible";
    document.getElementById("current-boosting-id").innerHTML = contractData.contractId,
        document.getElementById("current-boosting-class").innerHTML = contractData.class;
    document.getElementById("current-boosting-money").innerHTML = contractData.moneyReward;
    document.getElementById("current-boosting-reputation").innerHTML = contractData.repReward;
    document.getElementById("current-boosting-credits").innerHTML = contractData.creditReward;
    document.getElementById("boosting-member-0").innerHTML = playerName;
    document.getElementById("start-contract").disabled = false;
    document.getElementById("joinLobby").disabled = true;


    let hacks = 'NO';
    if (contractData.hacksRequired > 0) {
        hacks = 'SI';
    };
    document.getElementById("current-boosting-hacks").innerHTML = hacks;
    // Accept the contract and notify the server of the lobby being now active.
    fetch(`https://joni_boosting/contractAccepted`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ 'contractId': contractData.contractId })
    });
};

function showLobbyButtons(isVisible) {
    const lobbyButtons = document.querySelectorAll('.lobby-btn .sm-btn');
    lobbyButtons.forEach(button => {
        button.style.display = isVisible ? 'inline-block' : 'none';
    });
};

async function joinLobby() {
    Swal.fire({
        title: "Introduce el ID de la sala",
        input: "text",
        inputAttributes: { autocapitalize: "on" },
        background: "#222",
        color: 'white',
        showCancelButton: true,
        confirmButtonText: "Confirmar",
        allowOutsideClick: () => !Swal.isLoading()
    }).then((result) => {
        if (result.isConfirmed) {
            let playerName = document.getElementById("username").innerHTML;
            isInContract = true;
            fetch(`https://joni_boosting/joinLobby`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ 'contractId': result.value.toUpperCase(), 'playerName': playerName })
            });
            document.getElementById("joinLobby").disabled = true;
            window.parent.triggerNotification({ title: 'Conectando a la casa de Blako', text: 'Intentando unirse a la sala...', icon: 'info', timer: 3400 });
        };
    });
};

function showEditProfile() {
    document.getElementsByClassName('dashboard-boosting')[0].style.display = 'none';
    document.getElementsByClassName('dashboard-boosting')[0].style.opacity = 0;
    document.getElementsByClassName('dashboard-leaderboard')[0].style.display = 'none';
    document.getElementsByClassName('dashboard-leaderboard')[0].style.opacity = 0;
    document.getElementsByClassName('dashboard-shop')[0].style.display = 'none';
    document.getElementsByClassName('dashboard-shop')[0].style.opacity = 0;
    document.getElementsByClassName('dashboard-settings')[0].style.display = 'flex';
    setTimeout(() => {
        document.getElementsByClassName('dashboard-settings')[0].style.opacity = 1;
    }, 100);
};

function showBoostingDashboard() {
    document.getElementsByClassName('dashboard-settings')[0].style.display = 'none';
    document.getElementsByClassName('dashboard-settings')[0].style.opacity = 0;
    document.getElementsByClassName('dashboard-leaderboard')[0].style.display = 'none';
    document.getElementsByClassName('dashboard-leaderboard')[0].style.opacity = 0;
    document.getElementsByClassName('dashboard-shop')[0].style.display = 'none';
    document.getElementsByClassName('dashboard-shop')[0].style.opacity = 0;
    document.getElementsByClassName('dashboard-boosting')[0].style.display = 'block';
    setTimeout(() => {
        document.getElementsByClassName('dashboard-boosting')[0].style.opacity = 1;
    }, 100);
};

function showDashboard() {
    document.getElementsByClassName('dashboard-settings')[0].style.display = 'none';
    document.getElementsByClassName('dashboard-settings')[0].style.opacity = 0;
    document.getElementsByClassName('dashboard-boosting')[0].style.display = 'none';
    document.getElementsByClassName('dashboard-boosting')[0].style.opacity = 0;
    document.getElementsByClassName('dashboard-shop')[0].style.display = 'none';
    document.getElementsByClassName('dashboard-shop')[0].style.opacity = 0;
    document.getElementsByClassName('dashboard-leaderboard')[0].style.display = 'flex';
    setTimeout(() => {
        document.getElementsByClassName('dashboard-leaderboard')[0].style.opacity = 1;
    }, 100);
}

function showShopDashboard() {
    document.getElementsByClassName('dashboard-settings')[0].style.display = 'none';
    document.getElementsByClassName('dashboard-settings')[0].style.opacity = 0;
    document.getElementsByClassName('dashboard-boosting')[0].style.display = 'none';
    document.getElementsByClassName('dashboard-boosting')[0].style.opacity = 0;
    document.getElementsByClassName('dashboard-leaderboard')[0].style.display = 'none';
    document.getElementsByClassName('dashboard-leaderboard')[0].style.opacity = 0;
    document.getElementsByClassName('dashboard-shop')[0].style.display = 'flex';
    let username = document.getElementById("username").innerHTML;
    let credit = document.getElementById('credits').innerHTML;
    document.getElementById("user-shop-data").innerHTML = "Buenas " + username + ", dispones actualmente de <b>" + credit + "</b> créditos.";
    setTimeout(() => {
        document.getElementsByClassName('dashboard-shop')[0].style.opacity = 1;
    }, 100);
}

function updateUsername() {
    username = document.getElementById('usernameInput').value;
    oldUsername = document.getElementById("username").innerHTML;
    if (oldUsername == username) {
        window.parent.triggerNotification({ title: 'Cambio de nombre', text: 'El nombre es el mismo que el actual!', icon: 'error', timer: 2000 });
        return;
    };
    if (username.length > 20) {
        window.parent.triggerNotification({ title: 'Cambio de nombre', text: 'El nombre es demasiado largo!', icon: 'error', timer: 2000 });
        return;
    };
    fetch(`https://joni_boosting/changeProfileName`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ 'playerName': username })
    });
    window.parent.triggerNotification({ title: 'Cambio de nombre', text: 'Nombre cambiado con éxito!', icon: 'success', timer: 2000 });
};

function updateProfilePic() {
    profilePic = document.getElementById('profilePicInput').value;
    if (profilePic.length > 200) {
        window.parent.triggerNotification({ title: 'Cambio de imagen', text: 'La URL es demasiado larga!', icon: 'error', timer: 2000 });
        return;
    };
    if (!profilePic.startsWith('http://') && !profilePic.startsWith('https://')) {
        window.parent.triggerNotification({ title: 'Cambio de imagen', text: 'La URL debe empezar por http o https!', icon: 'error', timer: 2000 });
        return;
    };
    document.getElementById("profilePicInput").innerHTML = profilePic;
    fetch(`https://joni_boosting/changeProfilePic`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ 'playerPicture': profilePic })
    });
    window.parent.triggerNotification({ title: 'Cambio de nombre', text: 'Imagen de perfil cambiada con éxito!', icon: 'success', timer: 2000 });
};

function createBoostingContract({ id, imgSrc, vehicle, contractId, contractClass, contractCost, rep, money, credits, hacks }) {
    // Crear contenedor principal
    const contractDiv = document.createElement("div");
    contractDiv.classList.add("dashboard-contract", "invisible"); // Añadimos la clase 'invisible' aquí
    contractDiv.id = "boosting-contract-" + id;

    // Imagen del vehículo
    const imgElement = document.createElement("img");
    imgElement.src = imgSrc;
    contractDiv.appendChild(imgElement);

    // Vehículo
    const vehicleP = document.createElement("p");
    const vehicleSpan = document.createElement("span");
    vehicleSpan.classList.add("ls-1", "fs-0", "bold", "boosting-text");
    vehicleSpan.id = "boosting-vehicle";
    vehicleSpan.textContent = vehicle;
    vehicleP.appendChild(vehicleSpan);
    contractDiv.appendChild(vehicleP);

    // // Tiempo de expiración
    // const expireP = document.createElement("p");
    // const expireLabelSpan = document.createElement("span");
    // expireLabelSpan.classList.add("ls-1", "fs-07", "boosting-text");
    // expireLabelSpan.textContent = "Expira en ";
    // const expireTimeSpan = document.createElement("span");
    // expireTimeSpan.classList.add("ls-1", "fs-07", "boosting-text");
    // expireTimeSpan.id = "boosting-expire";
    // expireTimeSpan.textContent = expireTime + 'min';
    // expireP.appendChild(expireLabelSpan);
    // expireP.appendChild(expireTimeSpan);
    // contractDiv.appendChild(expireP);

    // ID del contrato
    const idP = document.createElement("p");
    const idLabelSpan = document.createElement("span");
    idLabelSpan.classList.add("ls-1", "fs-07", "boosting-text");
    idLabelSpan.textContent = "ID: ";
    const idSpan = document.createElement("span");
    idSpan.classList.add("ls-1", "fs-07", "boosting-text");
    idSpan.id = "boosting-id";
    idSpan.textContent = contractId;
    idP.appendChild(idLabelSpan);
    idP.appendChild(idSpan);
    contractDiv.appendChild(idP);

    // Clase
    const classP = document.createElement("p");
    const classLabelSpan = document.createElement("span");
    classLabelSpan.classList.add("ls-1", "fs-07", "boosting-text");
    classLabelSpan.textContent = "Clase: ";
    const classSpan = document.createElement("span");
    classSpan.classList.add("ls-1", "fs-07", "boosting-text");
    classSpan.id = "boosting-class";
    classSpan.textContent = contractClass;
    classP.appendChild(classLabelSpan);
    classP.appendChild(classSpan);
    contractDiv.appendChild(classP);

    // Coste del Contrato
    const costContractP = document.createElement("p");
    const costContractLabelSpan = document.createElement("span");
    costContractLabelSpan.classList.add("ls-1", "fs-07", "boosting-text");
    costContractLabelSpan.textContent = "Coste del contrato: ";
    const costContractSpan = document.createElement("span");
    costContractSpan.classList.add("ls-1", "fs-07", "boosting-text");
    costContractSpan.id = "boosting-costContract";
    costContractSpan.textContent = contractCost;
    costContractP.appendChild(costContractLabelSpan);
    costContractP.appendChild(costContractSpan);
    contractDiv.appendChild(costContractP);

    // Reputation
    const reputationP = document.createElement("p");
    const reputationLabelSpan = document.createElement("span");
    reputationLabelSpan.classList.add("ls-1", "fs-07", "boosting-text");
    reputationLabelSpan.textContent = "Reputación: ";
    const reputationSpan = document.createElement("span");
    reputationSpan.classList.add("ls-1", "fs-07", "boosting-text");
    reputationSpan.id = "boosting-reputation";
    reputationSpan.textContent = rep;
    reputationP.appendChild(reputationLabelSpan);
    reputationP.appendChild(reputationSpan);
    contractDiv.appendChild(reputationP);

    // Dinero
    const moneyP = document.createElement("p");
    const moneyLabelSpan = document.createElement("span");
    moneyLabelSpan.classList.add("ls-1", "fs-07", "boosting-text");
    moneyLabelSpan.textContent = "Dinero: ";
    const moneySpan = document.createElement("span");
    moneySpan.classList.add("ls-1", "fs-07", "boosting-text");
    moneySpan.id = "boosting-money";
    moneySpan.textContent = money;
    moneyP.appendChild(moneyLabelSpan);
    moneyP.appendChild(moneySpan);
    contractDiv.appendChild(moneyP);

    // Créditos
    const creditsP = document.createElement("p");
    const creditsLabelSpan = document.createElement("span");
    creditsLabelSpan.classList.add("ls-1", "fs-07", "boosting-text");
    creditsLabelSpan.textContent = "Créditos: ";
    const creditsSpan = document.createElement("span");
    creditsSpan.classList.add("ls-1", "fs-07", "boosting-text");
    creditsSpan.id = "boosting-credits";
    creditsSpan.textContent = credits;
    creditsP.appendChild(creditsLabelSpan);
    creditsP.appendChild(creditsSpan);
    contractDiv.appendChild(creditsP);

    // Hackeos
    const hacksP = document.createElement("p");
    const hacksLabelSpan = document.createElement("span");
    hacksLabelSpan.classList.add("ls-1", "fs-07", "boosting-text");
    hacksLabelSpan.textContent = "Hackeos: ";
    const hacksSpan = document.createElement("span");
    hacksSpan.classList.add("ls-1", "fs-07", "boosting-text");
    hacksSpan.id = "boosting-hacks";
    hacksSpan.textContent = hacks;
    hacksP.appendChild(hacksLabelSpan);
    hacksP.appendChild(hacksSpan);
    contractDiv.appendChild(hacksP);

    // Botón aceptar
    const acceptButton = document.createElement("button");
    acceptButton.id = "boosting-contract-" + id + "-accept";
    acceptButton.classList.add("shadow__btn_sm", "lightblue-btn");
    acceptButton.textContent = "Aceptar contrato";
    acceptButton.dataset.id = id;
    acceptButton.dataset.contractId = contractId;
    acceptButton.addEventListener('click', function() {
        acceptContract(this.dataset.id);
    });
    contractDiv.appendChild(acceptButton);

    // Botón rechazar
    const rejectButton = document.createElement("button");
    rejectButton.id = "boosting-contract-" + id + "-reject"; // Cambié aquí porque estaba duplicado el id
    rejectButton.classList.add("shadow__btn_sm", "red-btn");
    rejectButton.textContent = "Rechazar contrato";
    rejectButton.dataset.id = id;
    rejectButton.dataset.contractId = contractId;
    rejectButton.addEventListener('click', function() {
        rejectContract(this.dataset.id);
    });
    contractDiv.appendChild(rejectButton);

    const dashboardMain = document.getElementsByClassName("dashboard-main")[0];
    dashboardMain.appendChild(contractDiv);
    contractDiv.classList.remove("invisible");
};

function createRacerElement(racer, index) {
    const racerElement = document.createElement('div');
    racerElement.className = `racer ${index < 10 ? 'top-10' : 'rest'}`;

    if (index === 0) racerElement.classList.add('gold-border');
    else if (index === 1) racerElement.classList.add('silver-border');
    else if (index === 2) racerElement.classList.add('bronze-border');

    racerElement.innerHTML = `
        <div class="racer-info">
            <span class="position">${index + 1}</span>
            <img src="${racer.profile_picture}" alt="${racer.profile_name}" class="avatar">
            <span class="name">${racer.profile_name}</span>
        </div>
        <div class="stats">
            <div class="stat">
                <div class="stat-label">Contratos</div>
                <div class="stat-value">${racer.totalContracts}</div>
            </div>
            <div class="stat">
                <div class="stat-label">Reputación</div>
                <div class="stat-value">${racer.reputation.toLocaleString('de-DE')}</div>
            </div>
            <div class="stat">
                <div class="stat-label">Nivel</div>
                <div class="stat-value">${Math.floor(racer.profileXP / 100)}</div>
            </div>
        </div>
    `;
    return racerElement;
}

function createLeaderboard(leaderboardData) {
    // Reset the existing data in the leaderboard.
    document.getElementById('racers-list').innerHTML = '';
    const racersList = document.getElementById('racers-list');
    leaderboardData.forEach((racer, index) => {
        racersList.appendChild(createRacerElement(racer, index));
    });
}

function buyItem(item) {
    console.log('buyItem', item.dataset.name)
    let currentCredit = Number(document.getElementById('credits').innerHTML);
    console.log(currentCredit, item.dataset.creditprice)
    if (currentCredit >= item.dataset.creditprice) {
        window.parent.triggerNotification({ title: 'Consultando disponibilidad', text: 'Estamos consultando tu solvencia económica.', icon: 'info', timer: 3000, sound: 'notification' });
        fetch(`https://joni_boosting/buyItem`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ 'itemPackage': item.dataset.name })
        });
    } else {
        window.parent.triggerNotification({ title: '¡Imposible comprar!', text: 'Parece que no tienes suficientes créditos para comprar este artículo!', icon: 'error', timer: 3000, sound: 'error' });
    }
}

function createShopElement(item) {
    const itemElement = document.createElement('div');
    itemElement.className = 'shop-item'
    itemElement.innerHTML = `
        <div class="item-info">
            <img src="${item.item_image}" alt="${item.item_name}" class="item-photo">
            <div class='item-naming'>
                <span class="name">${item.item_label}</span>
                <span class="description">${item.item_description}</span>
                <span class="limit">Solo puedes comprar <b>${item.item_buyLimitPerRestart}</b> artículos por reinicio.</span>
            </div>
        </div>
        <div class="shop">
            <div class="stat">
                <div class="stat-label">Coste créditos</div>
                <div class="stat-value">${item.item_creditPrice}<span style='font-size: 0.5em';>cr</span></div>
            </div>
            <div class="stat">
                <div class="stat-label">Coste dinero</div>
                <div class="stat-value">${item.item_moneyPrice.toLocaleString('de-DE')}$</div>
            </div>
        </div>
        <button id="buyButton" data-name='${item.item_name}' data-creditprice=${item.item_creditPrice.toLocaleString('de-DE')} onclick="buyItem(this);" class="buy-button">
            Comprar
        </button>
    `;
    return itemElement;
}

function createShop(shopData) {
    // Reset the existing data in the leaderboard.
    document.getElementById('shop-list').innerHTML = '';
    const itemsList = document.getElementById('shop-list');
    shopData.forEach((item) => {
        itemsList.appendChild(createShopElement(item));
    });
}