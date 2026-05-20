const API = "http://localhost:3000";

async function loadDashboard(){

  try {

    // ===================================
    // FETCH ALL DATA
    // ===================================

    const [
      teamRes,
      standingsRes,
      matchesRes,
      newsRes
    ] = await Promise.all([

      fetch(`${API}/api/liverpool`),
      fetch(`${API}/api/standings`),
      fetch(`${API}/api/matches`),
      fetch(`${API}/api/news`)

    ]);

    const team =
      await teamRes.json();

    const standingsData =
      await standingsRes.json();

    const matchesData =
      await matchesRes.json();

    const newsData =
      await newsRes.json();

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

          <p>
            ${player.position || "Unknown"}
          </p>

          <p>
            ${player.nationality}
          </p>

        </div>

      `;

    });

    // ===================================
    // STANDINGS
    // ===================================

    const standings =
      standingsData.standings[0].table;

    const standingsDiv =
      document.getElementById("standings");

    standingsDiv.innerHTML = "";

    standings
      .slice(0, 10)
      .forEach(team => {

        standingsDiv.innerHTML += `

          <div class="
            table-row
            ${team.team.name === "Liverpool FC"
              ? "liverpool"
              : ""}
          ">

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

    if (liverpool) {

      document.getElementById("wins").innerText =
        liverpool.won;

      document.getElementById("draws").innerText =
        liverpool.draw;

      document.getElementById("losses").innerText =
        liverpool.lost;

      document.getElementById("points").innerText =
        liverpool.points;

    }

    // ===================================
    // NEXT MATCH
    // ===================================

    const upcomingMatches =
      matchesData.matches.filter(

        match =>

          match.status === "SCHEDULED" ||
          match.status === "TIMED"

      );

    const nextMatchDiv =
      document.getElementById("next-match");

    if (upcomingMatches.length > 0) {

      const nextMatch =
        upcomingMatches[0];

      nextMatchDiv.innerHTML = `

        <h3>

          ${nextMatch.homeTeam.name}

          vs

          ${nextMatch.awayTeam.name}

        </h3>

        <p>

          📅
          ${new Date(
            nextMatch.utcDate
          ).toLocaleString()}

        </p>

        <p>

          🏆
          ${nextMatch.competition.name}

        </p>

      `;

    } else {

      nextMatchDiv.innerHTML = `
        <p>No upcoming matches found.</p>
      `;

    }

    // ===================================
    // RECENT MATCHES
    // ===================================

    const recentMatchesDiv =
      document.getElementById(
        "recent-matches"
      );

    recentMatchesDiv.innerHTML = "";

    const finishedMatches =
      matchesData.matches
        .filter(
          match =>
            match.status === "FINISHED"
        )
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

    // ===================================
    // NEWS
    // ===================================

    const newsDiv =
      document.getElementById("news");

    newsDiv.innerHTML =
      `<div class="news-grid"></div>`;

    const newsGrid =
      document.querySelector(
        ".news-grid"
      );

    if (newsData.articles) {

      newsData.articles
        .slice(0, 6)
        .forEach(article => {

          newsGrid.innerHTML += `

            <div class="news-card">

              ${
                article.image
                  ? `
                    <img
                      src="${article.image}"
                      alt="news"
                    >
                  `
                  : ""
              }

              <h3>

                <a
                  href="${article.url}"
                  target="_blank"
                >

                  ${article.title}

                </a>

              </h3>

              <p>

                ${article.description || ""}

              </p>

            </div>

          `;

        });

    }

  } catch (error) {

    console.error(error);

  }

}

// ===================================
// LOAD DASHBOARD
// ===================================

loadDashboard();

// ===================================
// SQUAD DROPDOWN
// ===================================

const squadButton =
  document.getElementById(
    "toggle-squad"
  );

const playersDiv =
  document.getElementById(
    "players"
  );

const dropdownIcon =
  document.getElementById(
    "dropdown-icon"
  );

squadButton.addEventListener(
  "click",
  () => {

    playersDiv.classList.toggle(
      "hidden"
    );

    dropdownIcon.classList.toggle(
      "rotate"
    );

  }
);