const API = "http://localhost:3000";

async function loadDashboard(){

  // ===================================
  // TEAM DATA
  // ===================================

  const teamRes = await fetch(`${API}/api/liverpool`);
  const team = await teamRes.json();

  // ===================================
  // STANDINGS
  // ===================================

  const standingsRes =
    await fetch(`${API}/api/standings`);

  const standingsData =
    await standingsRes.json();

  // ===================================
  // MATCHES
  // ===================================

  const matchesRes =
    await fetch(`${API}/api/matches`);

  const matchesData =
    await matchesRes.json();

  // ===================================
  // HERO
  // ===================================

  document.getElementById("crest").src =
    team.crest;

  document.getElementById("club-name").innerText =
    team.name;

  document.getElementById("stadium").innerText =
    `🏟 ${team.venue}`;

  document.getElementById("manager").innerText =
    `👔 ${team.coach.name}`;

  // ===================================
  // PLAYERS
  // ===================================

  const players =
    document.getElementById("players");

  players.innerHTML = "";

  team.squad.forEach(player => {

    players.innerHTML += `

      <div class="player">

        <h3>${player.name}</h3>

        <p>${player.position || "Unknown"}</p>

        <p>${player.nationality}</p>

      </div>

    `;

  });

  // ===================================
  // STANDINGS TABLE
  // ===================================

  const standings =
    standingsData.standings[0].table;

  const standingsDiv =
    document.getElementById("standings");

  standingsDiv.innerHTML = "";

  standings.slice(0,10).forEach(team => {

    standingsDiv.innerHTML += `

      <div class="table-row
        ${team.team.name === "Liverpool FC"
          ? "liverpool"
          : ""}">

        <span>
          ${team.position}.
          ${team.team.name}
        </span>

        <span>
          ${team.points} pts
        </span>

      </div>

    `;

  });

  // ===================================
  // METRICS
  // ===================================

  const liverpool =
    standings.find(
      t => t.team.name === "Liverpool FC"
    );

  document.getElementById("wins").innerText =
    liverpool.won;

  document.getElementById("draws").innerText =
    liverpool.draw;

  document.getElementById("losses").innerText =
    liverpool.lost;

  document.getElementById("points").innerText =
    liverpool.points;

  // ===================================
  // NEXT MATCH
  // ===================================

  const upcomingMatches =
  matchesData.matches.filter(
    match =>
      match.status === "SCHEDULED" ||
      match.status === "TIMED"
  );

if (upcomingMatches.length > 0) {

  const nextMatch = upcomingMatches[0];

  document.getElementById("next-match").innerHTML = `

    <h3>
      ${nextMatch.homeTeam.name}
      vs
      ${nextMatch.awayTeam.name}
    </h3>

    <p>
      📅 ${new Date(nextMatch.utcDate).toLocaleString()}
    </p>

    <p>
      🏆 ${nextMatch.competition.name}
    </p>

  `;

} else {

  document.getElementById("next-match").innerHTML = `
    <p>No upcoming matches found.</p>
  `;

}
  // ===================================
  // RECENT MATCHES
  // ===================================

  const recentMatchesDiv =
    document.getElementById("recent-matches");

  recentMatchesDiv.innerHTML = "";

  const finishedMatches =
    matchesData.matches
      .filter(match => match.status === "FINISHED")
      .slice(-5)
      .reverse();

  finishedMatches.forEach(match => {

    recentMatchesDiv.innerHTML += `

      <div class="match">

        <h3>
          ${match.homeTeam.name}
          ${match.score.fullTime.home}
          -
          ${match.score.fullTime.away}
          ${match.awayTeam.name}
        </h3>

      </div>

    `;

  });

}


loadDashboard();