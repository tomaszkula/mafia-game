#include <amxmodx>
#include <colorchat>
#include <fakemeta>
#include <fun>
#include <hamsandwich>

#define PLUGIN "Mafia Game"
#define VERSION "4.0.2"
#define AUTHOR "tomkul777"

#define ADMIN_MAFIA ADMIN_LEVEL_A

#define MSG_ONE 1
#define VOTES_TIME 15

new const g_szGamePrefix[] = "[Mafia]";
new g_MafiaChatPrefix[] = "^4(^3M^4A^3F^4I^3A ^4C^3H^4A^3T^4)";

new const g_szFractionMenuPrefix[] = "\y[FRAKCJA]";
new const g_szFractionPrefix[] = "[Mafia :: Frakcja]";
new const g_CityVote1MenuPrefix[] = "\y[GLOS MIASTA #1]";
new const g_CityVote1Prefix[] = "[Mafia :: Glos Miasta #1]";
new const g_CityVote2MenuPrefix[] = "\y[GLOS MIASTA #2]";
new const g_CityVote2Prefix[] = "[Mafia :: Glos Miasta #2]";
new const g_MafiaVoteMenuPrefix[] = "\y[GLOS MAFII]";
new const g_MafiaVotePrefix[] = "[Mafia :: Glos Mafii]";
new const g_PriestVoteMenuPrefix[] = "\y[GLOS KSIEDZA]";
new const g_PriestVotePrefix[] = "[Mafia :: Glos Ksiedza]";
new const g_AgentVoteMenuPrefix[] = "\y[GLOS AGENTA]";
new const g_AgentVotePrefix[] = "[Mafia :: Glos Agenta]";
new const g_BarmanVoteMenuPrefix[] = "\y[GLOS BARMANA]";
new const g_BarmanVotePrefix[] = "[Mafia :: Glos Barmana]";
new const g_HunterVoteMenuPrefix[] = "\y[GLOS LOWCY]";
new const g_HunterVotePrefix[] = "[Mafia :: Glos Lowcy]";
new const g_JudgeVoteMenuPrefix[] = "\y[GLOS SEDZIEGO]";
new const g_JudgeVotePrefix[] = "[Mafia :: Glos Sedziego]";
new const g_SuicideVoteMenuPrefix[] = "\y[GLOS SAMOBOJCY]";
new const g_SuicideVotePrefix[] = "[Mafia :: Glos Samobojcy]";
new const g_VotesResultPrefix[] = "[Mafia :: Rezultat nocnych glosowan]";

new const g_VotesResultSimonPrefix[] = "[Mafia :: Info dla Prowadzacego]";

enum {
	CITY_MEMBER = 0,
	MAFIA_MEMBER = (1 << 0),
	PRIEST = (1 << 1),
	AGENT = (1 << 2),
	BARMAN = (1 << 3),
	HUNTER = (1 << 4),
	JUDGE = (1 << 5),
	SUICIDE = (1 << 6),
}

enum (+= 100) {
	TASK_INFO = 0,
	TASK_GAME_HUD,
	TASK_SET_DAY_TYPE,
	TASK_ACCEPT_FRACTION,
	TASK_VOTE_DELAY,
	TASK_VOTE,
	TASK_VOTE_DURING,
	TASK_KILL_DELAY,
}

enum {
	START = 0,
	CITY_VOTE1,
	CITY_VOTE1_END,
	CITY_VOTE2,
	CITY_VOTE2_END,
	HUNTER_VOTE,
	CITY_SLEEP,
	CITY_SLEEP_END,
	MAFIA_WAKE,
	MAFIA_WAKE_END,
	MAFIA_VOTE,
	MAFIA_VOTE_END,
	MAFIA_SLEEP,
	MAFIA_SLEEP_END,
	PRIEST_WAKE,
	PRIEST_WAKE_END,
	PRIEST_VOTE,
	PRIEST_VOTE_END,
	PRIEST_SLEEP,
	PRIEST_SLEEP_END,
	AGENT_WAKE,
	AGENT_WAKE_END,
	AGENT_VOTE,
	AGENT_VOTE_END,
	AGENT_SLEEP,
	AGENT_SLEEP_END,
	BARMAN_WAKE,
	BARMAN_WAKE_END,
	BARMAN_VOTE,
	BARMAN_VOTE_END,
	BARMAN_SLEEP,
	BARMAN_SLEEP_END,
	JUDGE_WAKE,
	JUDGE_WAKE_END,
	JUDGE_VOTE,
	JUDGE_VOTE_END,
	JUDGE_SLEEP,
	JUDGE_SLEEP_END,
	CITY_WAKE,
	CITY_WAKE_END,
	VOTES_RESULT,
	VOTES_RESULT_END
}
new g_eDayType;

new g_iSimon;
new bool:g_bGameStart, bool:g_bMovementBlock;

new g_ePlayers[33], g_ePlayersPropositions[33], g_eFraction;
new g_iVotesTimes[33];
new g_bHuntersSkills[33], g_iMafiaChoice;

new gameHud, mafiaHud;

new g_iVotesCounts[33], Array:g_aCityVotes, Array:g_aCityVotesCounts;
new g_iPriestsCounts[33], g_iAgentsCounts[33], g_iBarmansCounts[33] ,g_iJudgesCounts[33], g_iHunterTarget;

new randFractionsDefault[] = {1, 0, 0, 0, 0, 0, 0};
new randFractionsCurrent[] = {1, 0, 0, 0, 0, 0, 0};

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	new szMapName[50]; get_mapname(szMapName, charsmax(szMapName));
	if(!equal(szMapName, "jb_mafia"))
		set_fail_state("[Mafia] Plugin dziala tylko na mapie jb_mafia!");
	
	register_event("DeathMsg", "death_msg", "a");
	register_event("HLTV", "new_round", "a", "1=0", "2=0");
	register_logevent("end_round", 2, "1=Round_End");
	RegisterHam(Ham_Spawn, "player", "player_spawned", 1);
	register_forward(FM_ClientKill, "cmdKill")
	
	register_clcmd("say /mafia777", "game_menu");
	register_clcmd("say /mafia", "game_rules");
	register_clcmd("say", "mafia_chat");
	register_clcmd("say /zabij", "suicide_menu");
	
	pause("ac", "jbe_roulette.amxx");
	pause("ac", "adminlisten.amxx");
	
	set_task(240.0, "info_mod", TASK_INFO, .flags  = "b");
	
	set_game_status(false);
	
	gameHud = CreateHudSyncObj();
	mafiaHud = CreateHudSyncObj();
	
	g_aCityVotes = ArrayCreate(1, 5);
	g_aCityVotesCounts = ArrayCreate(1, 5);
}

public info_mod()
{
	ColorChat(0, GREEN, "%s [v%s] ^1Plugin stworzony przez ^3%s^1.", g_szGamePrefix, VERSION, AUTHOR);
	ColorChat(0, GREEN, "%s ^1Nie wiesz na czym polega ta zabawa? Wpisz ^3/mafia ^1zeby zobaczyc opis frakcji!", g_szGamePrefix);
}

public game_rules(id)
{
	show_motd(id, "mafia_rules.html", "Zasady gry w Mafie");
}

public client_disconnect(id) {
	stop_player_tasks(id);
	
	new nick[33]; get_user_name(id, nick, charsmax(nick));
	if(g_iSimon == id) 
	{
		ColorChat(0, GREEN, "%s ^1Prowadzacy gry w Mafie ^3%s ^1wyszedl z serwera.", g_szGamePrefix, nick);
		g_iSimon = 0;
	}
	else
	{
		if(g_ePlayers[id] & MAFIA_MEMBER == MAFIA_MEMBER) ColorChat(0, GREEN, "%s ^1Czlonek Mafii ^3%s ^1wyszedl z serwera.", g_szGamePrefix, nick);
		if(g_ePlayers[id] & PRIEST == PRIEST) ColorChat(0, GREEN, "%s ^1Ksiadz ^3%s ^1wyszedl z serwera.", g_szGamePrefix, nick);
		if(g_ePlayers[id] & AGENT == AGENT) ColorChat(0, GREEN, "%s ^1Agent ^3%s ^1wyszedl z serwera.", g_szGamePrefix, nick);
		if(g_ePlayers[id] & BARMAN == BARMAN) ColorChat(0, GREEN, "%s ^1Barman ^3%s ^1wyszedl z serwera.", g_szGamePrefix, nick);
		if(g_ePlayers[id] & HUNTER == HUNTER) ColorChat(0, GREEN, "%s ^1Lowca ^3%s ^1wyszedl z serwera.", g_szGamePrefix, nick);
		if(g_ePlayers[id] & JUDGE == JUDGE) ColorChat(0, GREEN, "%s ^1Sedzia ^3%s ^1wyszedl z serwera.", g_szGamePrefix, nick);
		if(g_ePlayers[id] & SUICIDE == SUICIDE) ColorChat(0, GREEN, "%s ^1Samobojca ^3%s ^1wyszedl z serwera.", g_szGamePrefix, nick);
	}
	
	g_ePlayers[id] = CITY_MEMBER;
	g_ePlayersPropositions[id] = CITY_MEMBER;
	g_iVotesTimes[id] = 0;
	
	if(g_bGameStart) {
		new mafiaCounts = 0, allCount = 0;
		static iPlayers[32], iNum, iPlayer;
		get_players(iPlayers, iNum);
		for(new i = 0; i < iNum; i++) {
			iPlayer = iPlayers[i];
			
			if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1 || iPlayer == id) continue;
			allCount++;
			
			if(g_ePlayers[iPlayer] & MAFIA_MEMBER != MAFIA_MEMBER) continue;
			mafiaCounts++;
		}
		
		if(mafiaCounts < 1) {
			ColorChat(0, GREEN, "%s ^1Ostatni czlonek Mafii opuscil gre. Miasto wygralo gre w Mafie!!!", g_szGamePrefix);
			set_game_status(false);
		} else if(allCount <= mafiaCounts) {
			ColorChat(0, GREEN, "%s ^1Ostatni czlonek miasta opuscil gre. Mafia wygrala gre w Mafie!!!", g_szGamePrefix);
			set_game_status(false);
		}
	}
	
	return PLUGIN_CONTINUE;
}

public death_msg() {
	new id = read_data(2);
	stop_player_tasks(id);
	night(id, short:0, 0);
	
	new nick[33]; get_user_name(id, nick, charsmax(nick));
	if(g_iSimon == id) 
	{	
		ColorChat(0, GREEN, "%s ^1Zginal prowadzacy gry w Mafie ^3%s^1.", g_szGamePrefix, nick);
		g_iSimon = 0;
	}
	else if(g_ePlayers[id] == CITY_MEMBER)
	{
		if(g_bGameStart && get_user_team(id) == 1) ColorChat(0, GREEN, "%s ^1Zginal ^3%s^1, ale kogo to obchodzi jak byl nikim.", g_szGamePrefix, nick);
	}
	else
	{
		if(g_ePlayers[id] & MAFIA_MEMBER == MAFIA_MEMBER) ColorChat(0, GREEN, "%s ^1Zginal ^3%s^1, ktory byl czlonkiem Mafii!", g_szGamePrefix, nick);
		if(g_ePlayers[id] & PRIEST == PRIEST) ColorChat(0, GREEN, "%s ^1Zginal ^3%s^1, ktory byl ksiedzem!", g_szGamePrefix, nick);
		if(g_ePlayers[id] & AGENT == AGENT) ColorChat(0, GREEN, "%s ^1Zginal ^3%s^1, ktory byl agentem!", g_szGamePrefix, nick);
		if(g_ePlayers[id] & BARMAN == BARMAN) ColorChat(0, GREEN, "%s ^1Zginal ^3%s^1, ktory byl barmanem!", g_szGamePrefix, nick);
		if(g_ePlayers[id] & HUNTER == HUNTER) ColorChat(0, GREEN, "%s ^1Zginal ^3%s^1, ktory byl lowca!", g_szGamePrefix, nick);
		if(g_ePlayers[id] & JUDGE == JUDGE) ColorChat(0, GREEN, "%s ^1Zginal ^3%s^1, ktory byl sedzia!", g_szGamePrefix, nick);
		if(g_ePlayers[id] & SUICIDE == SUICIDE) ColorChat(0, GREEN, "%s ^1Zginal ^3%s^1, ktory byl samobojca!", g_szGamePrefix, nick);
	}
	
	g_ePlayers[id] = CITY_MEMBER;
	g_ePlayersPropositions[id] = CITY_MEMBER;
	g_iVotesTimes[id] = 0;
	
	if(g_bGameStart) {
		new mafiaCounts = 0, allCount = 0;
		static iPlayers[32], iNum, iPlayer;
		get_players(iPlayers, iNum);
		for(new i = 0; i < iNum; i++) {
			iPlayer = iPlayers[i];
			
			if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1 || iPlayer == id) continue;
			allCount++;
			
			if(g_ePlayers[iPlayer] & MAFIA_MEMBER != MAFIA_MEMBER) continue;
			mafiaCounts++;
		}
		
		if(mafiaCounts < 1) {
			ColorChat(0, GREEN, "%s ^1Zginal ostatni czlonek Mafii. Miasto wygralo gre w Mafie!!!", g_szGamePrefix);
			set_game_status(false);
		} else if(allCount <= mafiaCounts) {
			ColorChat(0, GREEN, "%s ^1Zginal ostatni czlonek miasta. Mafia wygrala gre w Mafie!!!", g_szGamePrefix);
			set_game_status(false);
		}
	}
	
	return PLUGIN_CONTINUE;
}

public new_round() {
	if(g_bGameStart) set_game_status(false);
	
	return PLUGIN_CONTINUE;
}

public end_round() {
	if(g_bGameStart) set_game_status(false);
	
	return PLUGIN_CONTINUE;
}

public player_spawned(id) {
	if(get_user_team(id) == 2) set_user_godmode(id, 1);
	
	return PLUGIN_CONTINUE;
}

public cmdKill(id) {
	if(get_user_team(id) == 1 && g_bGameStart) return FMRES_SUPERCEDE;
	return FMRES_IGNORED;
}

public game_menu(id)
{
	if(!can_lead_mafia(id)) return PLUGIN_HANDLED;
	else
	{
		if(g_iSimon)
		{
			if(g_iSimon != id) 
			{
				ColorChat(id, GREEN, "%s ^1Posiadasz odpowiednie uprawnienia do zarzadzania zabawa, ale juz jest prowadzacy zabawy!", g_szGamePrefix);
				return PLUGIN_HANDLED;
			}
		}
		else
		{
			if(is_user_alive(id)) 
			{
				if(get_user_team(id) == 2) ColorChat(id, GREEN, "%s ^1Posiadasz odpowiednie uprawnienia do zarzadzania zabawa. Wez teraz prowadzacego z menu Mafii.", g_szGamePrefix);
				else 
				{
					ColorChat(id, GREEN, "%s ^1Posiadasz odpowiednie uprawnienia do zarzadzania zabawa, ale musisz byc w druzynie CT.", g_szGamePrefix);
					return PLUGIN_HANDLED;
				}
			}
			else 
			{
				ColorChat(id, GREEN, "%s ^1Posiadasz odpowiednie uprawnienia do zarzadzania zabawa, ale musisz byc tez wsrod zywych.", g_szGamePrefix);
				return PLUGIN_HANDLED;
			}
		}
	}
	
	new menu = menu_create("[Mafia] Menu Glowne", "game_menu_handler");
	new menuCallback = menu_makecallback("game_menu_callback");
	
	menu_additem(menu, "Zostan prowadzacym zabawy", .callback = menuCallback);
	
	if(g_iSimon == id)
	{
		if(g_bGameStart) menu_additem(menu, "\r[WYLACZ] \wGra w Mafie", .callback = menuCallback);
		else menu_additem(menu, "\y[WLACZ] \wGra w Mafie", .callback = menuCallback);
		
		if(g_bMovementBlock) menu_additem(menu, "\r[WYLACZ] \wBlokada ruchu", .callback = menuCallback);
		else menu_additem(menu, "\y[WLACZ] \wBlokada ruchu", .callback = menuCallback);
		
		if(g_bGameStart)
		{
			new priestsCount, agentsCount, barmansCount, judgesCount;
			static iPlayers[32], iNum, iPlayer;
			get_players(iPlayers, iNum);
			for(--iNum; iNum >= 0; iNum--) {
				iPlayer = iPlayers[iNum];
				
				if(g_ePlayers[iPlayer] & PRIEST == PRIEST) priestsCount++;
				if(g_ePlayers[iPlayer] & AGENT == AGENT) agentsCount++;
				if(g_ePlayers[iPlayer] & BARMAN == BARMAN) barmansCount++;
				if(g_ePlayers[iPlayer] & JUDGE == JUDGE) judgesCount++;
			}
			if(g_eDayType == START) menu_additem(menu, "\y[NASTEPNY TRYB] \wGlosowanie miasta #1", .callback = menuCallback);
			else if(g_eDayType == CITY_VOTE1) menu_additem(menu, "\r[TRYB TRWA] \wGlosowanie miasta #1", .callback = menuCallback);
			else if(g_eDayType == CITY_VOTE1_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wGlosowanie miasta #2", .callback = menuCallback);
			else if(g_eDayType == CITY_VOTE2) menu_additem(menu, "\r[TRYB TRWA] \wGlosowanie miasta #2", .callback = menuCallback);
			else if(g_eDayType == CITY_VOTE2_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wMiasto idzie spac", .callback = menuCallback);
			else if(g_eDayType == CITY_SLEEP) menu_additem(menu, "\r[TRYB TRWA] \wMiasto idzie spac", .callback = menuCallback);
			else if(g_eDayType == CITY_SLEEP_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wMafia budzi sie", .callback = menuCallback);
			else if(g_eDayType == MAFIA_WAKE) menu_additem(menu, "\r[TRYB TRWA] \wMafia budzi sie", .callback = menuCallback);
			else if(g_eDayType == MAFIA_WAKE_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wGlosowanie mafii", .callback = menuCallback);
			else if(g_eDayType == MAFIA_VOTE) menu_additem(menu, "\r[TRYB TRWA] \wGlosowanie mafii", .callback = menuCallback);
			else if(g_eDayType == MAFIA_VOTE_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wMafia idzie spac", .callback = menuCallback);
			else if(g_eDayType == MAFIA_SLEEP) menu_additem(menu, "\r[TRYB TRWA] \wMafia idzie spac", .callback = menuCallback);
			else if(g_eDayType == MAFIA_SLEEP_END) {
				if(priestsCount > 0) menu_additem(menu, "\y[NASTEPNY TRYB] \wKsieza budza sie", .callback = menuCallback);
				else if(agentsCount > 0) menu_additem(menu, "\y[NASTEPNY TRYB] \wAgenci budza sie", .callback = menuCallback);
				else if(barmansCount > 0) menu_additem(menu, "\y[NASTEPNY TRYB] \wBarmani budza sie", .callback = menuCallback);
				else if(judgesCount > 0) menu_additem(menu, "\y[NASTEPNY TRYB] \wSedziowie budza sie", .callback = menuCallback);
				else menu_additem(menu, "\y[NASTEPNY TRYB] \wMiasto budzi sie", .callback = menuCallback);
			}
			else if(g_eDayType == PRIEST_WAKE) menu_additem(menu, "\r[TRYB TRWA] \wKsieza budza sie", .callback = menuCallback);
			else if(g_eDayType == PRIEST_WAKE_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wGlosowanie ksiezy", .callback = menuCallback);
			else if(g_eDayType == PRIEST_VOTE) menu_additem(menu, "\r[TRYB TRWA] \wGlosowanie ksiezy", .callback = menuCallback);
			else if(g_eDayType == PRIEST_VOTE_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wKsieza ida spac", .callback = menuCallback);
			else if(g_eDayType == PRIEST_SLEEP) menu_additem(menu, "\r[TRYB TRWA] \wKsieza ida spac", .callback = menuCallback);
			else if(g_eDayType == PRIEST_SLEEP_END) {
				if(agentsCount > 0) menu_additem(menu, "\y[NASTEPNY TRYB] \wAgenci budza sie", .callback = menuCallback);
				else if(barmansCount > 0) menu_additem(menu, "\y[NASTEPNY TRYB] \wBarmani budza sie", .callback = menuCallback);
				else if(judgesCount > 0) menu_additem(menu, "\y[NASTEPNY TRYB] \wSedziowie budza sie", .callback = menuCallback);
				else menu_additem(menu, "\y[NASTEPNY TRYB] \wMiasto budzi sie", .callback = menuCallback);
			}
			else if(g_eDayType == AGENT_WAKE) menu_additem(menu, "\r[TRYB TRWA] \wAgenci budza sie", .callback = menuCallback);
			else if(g_eDayType == AGENT_WAKE_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wGlosowanie agentow", .callback = menuCallback);
			else if(g_eDayType == AGENT_VOTE) menu_additem(menu, "\r[TRYB TRWA] \wGlosowanie agentow", .callback = menuCallback);
			else if(g_eDayType == AGENT_VOTE_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wAgenci ida spac", .callback = menuCallback);
			else if(g_eDayType == AGENT_SLEEP) menu_additem(menu, "\r[TRYB TRWA] \wAgenci ida spac", .callback = menuCallback);
			else if(g_eDayType == AGENT_SLEEP_END) {
				if(barmansCount > 0) menu_additem(menu, "\y[NASTEPNY TRYB] \wBarmani budza sie", .callback = menuCallback);
				else if(judgesCount > 0) menu_additem(menu, "\y[NASTEPNY TRYB] \wSedziowie budza sie", .callback = menuCallback);
				else menu_additem(menu, "\y[NASTEPNY TRYB] \wMiasto budzi sie", .callback = menuCallback);
			}
			else if(g_eDayType == BARMAN_WAKE) menu_additem(menu, "\r[TRYB TRWA] \wBarmani budza sie", .callback = menuCallback);
			else if(g_eDayType == BARMAN_WAKE_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wGlosowanie barmanow", .callback = menuCallback);
			else if(g_eDayType == BARMAN_VOTE) menu_additem(menu, "\r[TRYB TRWA] \wGlosowanie barmanow", .callback = menuCallback);
			else if(g_eDayType == BARMAN_VOTE_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wBarmani ida spac", .callback = menuCallback);
			else if(g_eDayType == BARMAN_SLEEP) menu_additem(menu, "\r[TRYB TRWA] \wBarmani ida spac", .callback = menuCallback);
			else if(g_eDayType == BARMAN_SLEEP_END) {
				if(judgesCount > 0) menu_additem(menu, "\y[NASTEPNY TRYB] \wSedziowie budza sie", .callback = menuCallback);
				else menu_additem(menu, "\y[NASTEPNY TRYB] \wMiasto budzi sie", .callback = menuCallback);
			}
			else if(g_eDayType == JUDGE_WAKE) menu_additem(menu, "\r[TRYB TRWA] \wSedziowie budza sie", .callback = menuCallback);
			else if(g_eDayType == JUDGE_WAKE_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wGlosowanie sedziow", .callback = menuCallback);
			else if(g_eDayType == JUDGE_VOTE) menu_additem(menu, "\r[TRYB TRWA] \wGlosowanie sedziow", .callback = menuCallback);
			else if(g_eDayType == JUDGE_VOTE_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wSedziowie ida spac", .callback = menuCallback);
			else if(g_eDayType == JUDGE_SLEEP) menu_additem(menu, "\r[TRYB TRWA] \wSedziowie ida spac", .callback = menuCallback);
			else if(g_eDayType == JUDGE_SLEEP_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wMiasto budzi sie", .callback = menuCallback);
			else if(g_eDayType == CITY_WAKE) menu_additem(menu, "\r[TRYB TRWA] \wMiasto budzi sie", .callback = menuCallback);
			else if(g_eDayType == CITY_WAKE_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wRezultat nocnych glosowan", .callback = menuCallback);
			else if(g_eDayType == VOTES_RESULT) menu_additem(menu, "\r[TRYB TRWA] \wRezultat nocnych glosowan", .callback = menuCallback);
			else if(g_eDayType == VOTES_RESULT_END) menu_additem(menu, "\y[NASTEPNY TRYB] \wGlosowanie miasta #1", .callback = menuCallback);
		}
		else menu_additem(menu, "\d[TRYB DNIA]", .callback = menuCallback);
	}
	else
	{
		if(g_bGameStart) menu_additem(menu, "\d[WYLACZ] Gra w Mafie", .callback = menuCallback);
		else menu_additem(menu, "\d[WLACZ] Gra w Mafie", .callback = menuCallback);
		
		if(g_bMovementBlock) menu_additem(menu, "\d[WYLACZ] Blokada ruchu", .callback = menuCallback);
		else menu_additem(menu, "\d[WLACZ] Blokada ruchu", .callback = menuCallback);
		
		menu_additem(menu, "\d[TRYB DNIA]", .callback = menuCallback);
	}
	
	
	menu_additem(menu, "Manualna obsluga graczy", .callback = menuCallback);
	menu_additem(menu, "Przydziel frakcje losowo", .callback = menuCallback);
	
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(menu, MPROP_BACKNAME, "Poprzednia strona");
	menu_setprop(menu, MPROP_NEXTNAME, "Nastepna strona");
	menu_setprop(menu, MPROP_EXITNAME, "Wyjdz");
	menu_display(id, menu);
	
	return PLUGIN_HANDLED;
}

public game_menu_callback(id, menu, item)
{
	switch(item)
	{
		case 0:
		{
			if(g_iSimon) return ITEM_DISABLED;
			else return ITEM_ENABLED;
		}
		
		case 3:
		{
			if(g_iSimon == id && g_bGameStart) return ITEM_ENABLED;
			else return ITEM_DISABLED;
		}
		
		default:
		{
			if(g_iSimon == id) return ITEM_ENABLED;
			else return ITEM_DISABLED;
		}
	}
	
	return ITEM_ENABLED;
}

public game_menu_handler(id, menu, item)
{
	if(!can_lead_mafia(id)) return PLUGIN_HANDLED;
	else
	{
		if(g_iSimon)
		{
			if(g_iSimon != id) return PLUGIN_HANDLED;
		}
		else
		{
			if(!is_user_alive(id)) return PLUGIN_HANDLED;
			if(get_user_team(id) != 2) return PLUGIN_HANDLED;
		}
	}
	
	if(item == MENU_EXIT) return PLUGIN_HANDLED;
	
	switch(item) {
		case 0:
		{
			if(g_iSimon) 
			{
				ColorChat(0, GREEN, "%s ^1Ktos cie ubiegl i juz jest prowadzacy gry w Mafie!", g_szGamePrefix);
				return PLUGIN_HANDLED;
			}
			g_iSimon = id;
			
			new name[50]; get_user_name(id, name, charsmax(name));
			ColorChat(0, GREEN, "%s ^1Nowym prowadzacym gry w Mafie zostal ^3%s^1.", g_szGamePrefix, name);
			
			game_menu(id);
		}
		
		case 1:
		{
			if(g_iSimon != id) return PLUGIN_HANDLED;
			
			if(g_bGameStart)
			{
				end_game_menu(id);
			}
			else
			{
				set_game_status(true);
				game_menu(id);
				
				ColorChat(0, GREEN, "%s ^1Prowadzacy gry w Mafie ^4wlaczyl ^1zabawe!", g_szGamePrefix);
			}	
		}
		
		case 2:
		{
			if(g_iSimon != id) return PLUGIN_HANDLED;
			
			set_movement_status(!g_bMovementBlock);
			
			if(g_bMovementBlock) ColorChat(0, GREEN, "%s ^1Blokada ruchu zostala ^4aktywowana ^1przez prowadzacego gry w Mafie!", g_szGamePrefix);
			else ColorChat(0, GREEN, "%s ^1Blokada ruchu zostala ^3dezaktywowana ^1przez prowadzacego gry w Mafie!", g_szGamePrefix);
			
			game_menu(id);
		}
		
		case 3:
		{
			if(g_iSimon != id) return PLUGIN_HANDLED;
			
			change_day_type();
			game_menu(id);
		}
		
		case 4:
		{
			if(g_iSimon != id) return PLUGIN_HANDLED;
			
			users_manager_menu(id, 0);
		}
		
		case 5:
		{
			if(g_iSimon != id) return PLUGIN_HANDLED;
			
			users_manager_random_menu(id, 0);
		}
	}
	
	return PLUGIN_HANDLED;
}

public game_hud() {
	new allCount = 0, mafiaCount = 0, priestCount = 0, agentCount = 0, barmanCount = 0, hunterCount = 0, judgeCount = 0, suicideCount = 0;
	new mafiaMembers[400] = "[Czlonkowie Mafii]^n";
	
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		
		allCount++;
		
		if(g_ePlayers[iPlayer] & MAFIA_MEMBER) 
		{
			mafiaCount++;
			
			new name[50]; get_user_name(iPlayer, name, charsmax(name));
			formatex(mafiaMembers, charsmax(mafiaMembers), "%s[%d] %s^n", mafiaMembers, mafiaCount, name);
		}
		if(g_ePlayers[iPlayer] & PRIEST) priestCount++;
		if(g_ePlayers[iPlayer] & AGENT) agentCount++;
		if(g_ePlayers[iPlayer] & BARMAN) barmanCount++;
		if(g_ePlayers[iPlayer] & HUNTER) hunterCount++;
		if(g_ePlayers[iPlayer] & JUDGE) judgeCount++;
		if(g_ePlayers[iPlayer] & SUICIDE) suicideCount++;
	}
	
	new title[50]; formatex(title, charsmax(title), "[Gra w Mafie] [Zywi uczestnicy : %d]^n", allCount);
	new szMafia[30] = ""; if(mafiaCount > 0) formatex(szMafia, charsmax(szMafia), "[%d] Czlonkowie Mafii^n", mafiaCount);
	new szPriests[30] = ""; if(priestCount > 0) formatex(szPriests, charsmax(szPriests), "[%d] Ksieza^n", priestCount);
	new szAgents[30] = ""; if(agentCount > 0) formatex(szAgents, charsmax(szAgents), "[%d] Agenci^n", agentCount);
	new szBarmans[30] = ""; if(barmanCount > 0) formatex(szBarmans, charsmax(szBarmans), "[%d] Barmani^n", barmanCount);
	new szHunters[30] = ""; if(hunterCount > 0) formatex(szHunters, charsmax(szHunters), "[%d] Lowcy^n", hunterCount);
	new szJudges[30] = ""; if(judgeCount > 0) formatex(szJudges, charsmax(szJudges), "[%d] Sedziowie^n", judgeCount);
	new szSuicides[30] = ""; if(suicideCount > 0) formatex(szSuicides, charsmax(szSuicides), "[%d] Samobojcy^n", suicideCount);
	
	new msg[300];
	formatex(msg, charsmax(msg), "%s%s%s%s%s%s%s%s", title, szMafia, szPriests, szAgents, szBarmans, szHunters, szJudges, szSuicides);
	
	set_hudmessage(0, 255, 42, 0.75, 0.2, 0, 6.0, 1.0);
	ShowSyncHudMsg(0, gameHud, msg);
	
	
	set_hudmessage(0, 255, 42, 0.75, 0.5, 0, 6.0, 1.0);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		if(g_ePlayers[iPlayer] & MAFIA_MEMBER != MAFIA_MEMBER)  continue;
		
		ShowSyncHudMsg(iPlayer, mafiaHud, mafiaMembers);
	}
}

public end_game_menu(id)
{
	if(g_iSimon != id) return PLUGIN_HANDLED;
	
	new menu = menu_create("[Mafia] Na pewno chcesz zakonczyc gre?", "end_game_menu_handler");
	menu_additem(menu, "Tak");
	menu_additem(menu, "Nie, to byla pomylka");
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	menu_display(id, menu);
	
	return PLUGIN_HANDLED;
}

public end_game_menu_handler(id, menu, item)
{
	if(g_iSimon != id) return PLUGIN_HANDLED;
	
	switch(item)
	{
		case 0:
		{
			set_game_status(false);
			game_menu(id);
			
			ColorChat(0, GREEN, "%s ^1Prowadzacy gry w Mafie ^3wylaczyl ^1zabawe!", g_szGamePrefix);
		}
		
		case 1:
		{
			game_menu(id);
		}
	}
	
	return PLUGIN_HANDLED;
}

//////////////////////////////////////////////////////////////////////////////////
public change_day_type() {
	new priestsCount, agentsCount, barmansCount, judgesCount;
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(--iNum; iNum >= 0; iNum--) {
		iPlayer = iPlayers[iNum];
		
		if(g_ePlayers[iPlayer] & PRIEST == PRIEST) priestsCount++;
		if(g_ePlayers[iPlayer] & AGENT == AGENT) agentsCount++;
		if(g_ePlayers[iPlayer] & BARMAN == BARMAN) barmansCount++;
		if(g_ePlayers[iPlayer] & JUDGE == JUDGE) judgesCount++;
	}
	
	switch(g_eDayType) {
		case START: full_vote(CITY_VOTE1);
		case CITY_VOTE1_END: city_vote2();
		case CITY_VOTE2_END: fraction_sleep(CITY_SLEEP);
		case CITY_SLEEP_END: fraction_wake(MAFIA_WAKE);
		case MAFIA_WAKE_END: full_vote(MAFIA_VOTE);
		case MAFIA_VOTE_END: fraction_sleep(MAFIA_SLEEP);
		case MAFIA_SLEEP_END: {
			if(priestsCount > 0) fraction_wake(PRIEST_WAKE);
			else if(agentsCount > 0) fraction_wake(AGENT_WAKE);
			else if(barmansCount > 0) fraction_wake(BARMAN_WAKE);
			else if(judgesCount > 0) fraction_wake(JUDGE_WAKE);
			else fraction_wake(CITY_WAKE);
		}
		case PRIEST_WAKE_END: full_vote(PRIEST_VOTE);
		case PRIEST_VOTE_END: fraction_sleep(PRIEST_SLEEP);
		case PRIEST_SLEEP_END: {
			if(agentsCount > 0) fraction_wake(AGENT_WAKE);
			else if(barmansCount > 0) fraction_wake(BARMAN_WAKE);
			else if(judgesCount > 0) fraction_wake(JUDGE_WAKE);
			else fraction_wake(CITY_WAKE);
		}
		case AGENT_WAKE_END: full_vote(AGENT_VOTE);
		case AGENT_VOTE_END: fraction_sleep(AGENT_SLEEP);
		case AGENT_SLEEP_END: {
			if(barmansCount > 0) fraction_wake(BARMAN_WAKE);
			else if(judgesCount > 0) fraction_wake(JUDGE_WAKE);
			else fraction_wake(CITY_WAKE);
		}
		case BARMAN_WAKE_END: full_vote(BARMAN_VOTE);
		case BARMAN_VOTE_END: fraction_sleep(BARMAN_SLEEP);
		case BARMAN_SLEEP_END: {
			if(judgesCount > 0) fraction_wake(JUDGE_WAKE);
			else fraction_wake(CITY_WAKE);
		}
		case JUDGE_WAKE_END: full_vote(JUDGE_VOTE);
		case JUDGE_VOTE_END: fraction_sleep(JUDGE_SLEEP);
		case JUDGE_SLEEP_END: fraction_wake(CITY_WAKE);
		case CITY_WAKE_END: votes_result();
		case VOTES_RESULT_END: full_vote(CITY_VOTE1);
	}
}

//////////////////////////////////////////City Vote 1
public city_vote1_result() {
	if(ArraySize(g_aCityVotes) > 0) {
		ArrayClear(g_aCityVotes);
		ArrayClear(g_aCityVotesCounts);
	}
	
	new biggest = 0, smaller = 0;
	new biggestCount = 0, smallerCount = 0;
	
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		
		if(g_iVotesCounts[iPlayer] > biggest) {
			smaller = biggest;
			smallerCount = biggestCount;
			
			biggest = g_iVotesCounts[iPlayer];
			biggestCount = 1;
		}
		else if(g_iVotesCounts[iPlayer] == biggest && biggest != 0) biggestCount++;
		else if(g_iVotesCounts[iPlayer] > smaller) {
			smaller = g_iVotesCounts[iPlayer];
			smallerCount = 1;
		} else if(g_iVotesCounts[iPlayer] == smaller && smaller != 0) smallerCount++;
	}
	
	if(biggestCount == 0) {
		ColorChat(0, GREEN, "%s ^1Miasto nikogo nie wybralo, wiec tym razem nikt nie zginie.", g_CityVote1Prefix);
		ColorChat(0, GREEN, "%s ^1Glosowanie miasta #1 zostalo zakonczone.", g_szGamePrefix);
		
		new szDayType[10];
		num_to_str(CITY_VOTE2_END, szDayType, charsmax(szDayType));
		set_task(0.5, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
		
		return PLUGIN_HANDLED;
	} else {
		if(biggestCount == 1) {
			if(smallerCount == 0) {
				new id;
				for(new i = 0; i < iNum; i++) {
					iPlayer = iPlayers[i];
					
					if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
					
					if(g_iVotesCounts[iPlayer] == biggest) {
						id = iPlayer;
						break;
					}
				}
				
				new nick[33];
				get_user_name(id, nick, charsmax(nick));
				ColorChat(0, GREEN, "%s ^1Miasto jednoglosnie wybralo ^3%s ^1(^4%d ^1glosow) do zabicia!", g_CityVote1Prefix, nick, biggest);
				
				if(g_ePlayers[id] & HUNTER == HUNTER && g_bHuntersSkills[id]) {
					ColorChat(0, GREEN, "%s ^3%s ^1jest ^3lowca^1! To jego ostatnia szansa na odwrocenie losu!", g_HunterVotePrefix, nick);
					g_bHuntersSkills[id] = false;
					
					hunter_vote(id);
				} else {
					new szPlayer[3]; num_to_str(id, szPlayer, charsmax(szPlayer));
					set_task(0.5, "user_kill_delay", TASK_KILL_DELAY, szPlayer, charsmax(szPlayer));
					
					new szDayType[10];
					num_to_str(CITY_VOTE2_END, szDayType, charsmax(szDayType));
					set_task(1.0, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
				}
				
				return PLUGIN_HANDLED;
			} else {
				for(new i = 0; i < iNum; i++) {
					iPlayer = iPlayers[i];
					
					if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
					
					if(g_iVotesCounts[iPlayer] == biggest) {
						ArrayPushCell(g_aCityVotes, iPlayer);
						ArrayPushCell(g_aCityVotesCounts, g_iVotesCounts[iPlayer]);
					}
				}
				
				for(new i = 0; i < iNum; i++) {
					iPlayer = iPlayers[i];
					
					if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
					
					if(g_iVotesCounts[iPlayer] == smaller) {
						ArrayPushCell(g_aCityVotes, iPlayer);
						ArrayPushCell(g_aCityVotesCounts, g_iVotesCounts[iPlayer]);
					}
				}
			}
		} else {
			for(new i = 0; i < iNum; i++) {
				iPlayer = iPlayers[i];
				
				if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
				
				if(g_iVotesCounts[iPlayer] == biggest) {
					ArrayPushCell(g_aCityVotes, iPlayer);
					ArrayPushCell(g_aCityVotesCounts, g_iVotesCounts[iPlayer]);
				}
			}
		}
	}
	
	ColorChat(0, GREEN, "%s ^1Osoby wybrane do dogrywki:", g_CityVote1Prefix);
	for(new i = 0; i < ArraySize(g_aCityVotes); i++) {
		new nick[33];
		get_user_name(ArrayGetCell(g_aCityVotes, i), nick, charsmax(nick));
		ColorChat(0, GREEN, " %s ^1Osoba ^4nr %d^1: ^3%s ^1(^4%d ^1glosow)", g_CityVote1Prefix, i + 1, nick, ArrayGetCell(g_aCityVotesCounts, i));
	}
	
	new szDayType[10];
	num_to_str(CITY_VOTE1_END, szDayType, charsmax(szDayType));
	set_task(1.0, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
	
	return PLUGIN_HANDLED;
}
//////////////////////////////////////////City Vote 2
public city_vote2() {
	g_eDayType = CITY_VOTE2;
	
	if(!judge_result()) {
		static iPlayers[32], iNum, iPlayer;
		get_players(iPlayers, iNum);
		for(new i = 0; i < iNum; i++) {
			iPlayer = iPlayers[i];
			
			g_iVotesCounts[iPlayer] = 0;
		}
		
		ColorChat(0, GREEN, "%s ^1Potrzebna jest dogrywka, wiec czas na glosowanie miasta #2!", g_CityVote2Prefix);
		ColorChat(0, GREEN, "%s ^1Za^3 3s ^1rozpocznie sie vote w celu wybrania osoby do zabicia!", g_CityVote2Prefix);
		set_task(1.5, "city_vote2_delay", TASK_VOTE_DELAY);
	} else {
		new szDayType[10];
		num_to_str(CITY_VOTE2_END, szDayType, charsmax(szDayType));
		set_task(1.0, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
	}
}

public judge_result() {
	if(ArraySize(g_aCityVotes) != 2) return false;
	
	new bool:convicted = false;
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		if(g_ePlayers[iPlayer] & JUDGE != JUDGE) continue;
		
		for(new j = 0; j < ArraySize(g_aCityVotes); j++) {
			new id = ArrayGetCell(g_aCityVotes, j);
			if(g_iJudgesCounts[iPlayer] == id) {
				new nick[33];
				get_user_name(id, nick, charsmax(nick));
				new szPlayer[3];
				num_to_str(id, szPlayer, charsmax(szPlayer));
				ColorChat(0, GREEN, "%s ^1Sedzia skazal ^3%s ^1na smierc!", g_JudgeVotePrefix, nick);
				convicted = true;
				set_task(0.5, "user_kill_delay", TASK_KILL_DELAY + id, szPlayer, charsmax(szPlayer));
			}
		}
	}
	
	return convicted;
}

public city_vote2_delay() {
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		if(g_ePlayers[iPlayer] & JUDGE == JUDGE) g_iJudgesCounts[iPlayer] = 0;
		
		g_iVotesTimes[iPlayer] = VOTES_TIME;
		new szPlayer[3]; num_to_str(iPlayer, szPlayer, charsmax(szPlayer));
		set_task(1.0, "city_vote2_menu", TASK_VOTE + iPlayer, szPlayer, charsmax(szPlayer), "b");
	}
	
	set_task(1.0, "is_vote_during", TASK_VOTE_DURING, .flags = "b");
}

public city_vote2_menu(szPlayer[]) {
	new id = str_to_num(szPlayer);
	
	new m1, m2, page;
	player_menu_info(id, m1, m2, page);
	
	new title[60];
	formatex(title, charsmax(title), "[%ds] %s \wWybierz osobe do zabicia", g_iVotesTimes[id], g_CityVote2MenuPrefix);

	new cityVote2Menu = menu_create(title, "vote_handler");
	
	static iPlayer;
	for(new i = 0; i < ArraySize(g_aCityVotes); i++) {
		iPlayer = ArrayGetCell(g_aCityVotes ,i);
		
		new nick[33];
		get_user_name(iPlayer, nick, charsmax(nick));
		new szIdPlayer[3];
		num_to_str(iPlayer, szIdPlayer, charsmax(szIdPlayer));
		menu_additem(cityVote2Menu, nick, szIdPlayer);
	}
	
	menu_setprop(cityVote2Menu, MPROP_EXIT, MEXIT_NEVER);
	menu_setprop(cityVote2Menu, MPROP_BACKNAME, "Poprzednia strona");
	menu_setprop(cityVote2Menu, MPROP_NEXTNAME, "Nastepna strona");
	menu_display(id, cityVote2Menu, page);
	
	g_iVotesTimes[id]--;
	if(g_iVotesTimes[id] < 0) {
		remove_task(TASK_VOTE + id);
		show_menu(id, 0, "^n", 1);
		g_iVotesTimes[id] = 0;
		
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_HANDLED;
}

public city_vote2_result() {
	new biggest = 0, biggestCount = 0;
	
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		//if(get_user_team(iPlayer) != 1) continue;
		
		if(g_iVotesCounts[iPlayer] > biggestCount) {
			biggestCount = g_iVotesCounts[iPlayer];
			biggest = iPlayer;
		}
	}
	
	if(biggestCount == 0) {
		ColorChat(0, GREEN, "%s ^1Miasto nikogo nie wybralo, wiec tym razem nikt nie zginie.", g_CityVote2Prefix);
		ColorChat(0, GREEN, "%s ^1Glosowanie miasta #2 zostalo zakonczone.", g_szGamePrefix);
		
		new szDayType[10];
		num_to_str(CITY_VOTE2_END, szDayType, charsmax(szDayType));
		set_task(1.0, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
	} else {
		new nick[33];
		get_user_name(biggest, nick, charsmax(nick));
		ColorChat(0, GREEN, "%s ^1Miasto ostatecznie wybralo ^3%s ^4(%d glosow) ^1do zabicia!", g_CityVote2Prefix, nick, biggestCount);
		
		if(!is_user_alive(biggest)) 
		{
			new szDayType[10];
			num_to_str(CITY_VOTE2_END, szDayType, charsmax(szDayType));
			set_task(1.5, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
			return PLUGIN_HANDLED;
		}
		
		if(g_ePlayers[biggest] & HUNTER == HUNTER && g_bHuntersSkills[biggest]) {
			ColorChat(0, GREEN, "%s ^3%s ^1jest ^3lowca^1! To jego ostatnia szansa na odwrocenie losu!", g_HunterVotePrefix, nick);
			g_bHuntersSkills[biggest] = false;
			
			hunter_vote(biggest);
		} else {
			new szPlayer[3]; num_to_str(biggest, szPlayer, charsmax(szPlayer));
			set_task(0.5, "user_kill_delay", TASK_KILL_DELAY, szPlayer, charsmax(szPlayer));
			
			new szDayType[10];
			num_to_str(CITY_VOTE2_END, szDayType, charsmax(szDayType));
			set_task(1.5, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
		}
	}
	
	return PLUGIN_HANDLED;
}
//////////////////////////////////////////


//////////////////////////////////////////Hunter Vote
public hunter_vote(id) {
	g_eDayType = HUNTER_VOTE;
	
	g_iHunterTarget = 0;
	
	ColorChat(0, GREEN, "%s ^1Czas na glosowanie lowcy!", g_HunterVotePrefix);
	
	new szPlayer[3];
	num_to_str(id, szPlayer, charsmax(szPlayer));
	set_task(1.5, "hunter_vote_delay", TASK_VOTE_DELAY, szPlayer, charsmax(szPlayer));
}

public hunter_vote_delay(szPlayer[]) {
	new iPlayer = str_to_num(szPlayer);
	
	g_iVotesTimes[iPlayer] = VOTES_TIME;
	set_task(1.0, "full_vote_menu", TASK_VOTE + iPlayer, szPlayer, 3, "b");
	
	set_task(1.0, "is_vote_during", TASK_VOTE_DURING, .flags = "b");
}

public hunter_vote_result() {
	if(g_iHunterTarget) {
		new nick[33]; get_user_name(g_iHunterTarget, nick, charsmax(nick));
		ColorChat(0, GREEN, "%s ^3Lowca ^1wybral ^3%s ^1do zabicia!", g_HunterVotePrefix, nick);
		
		new szId[3]; num_to_str(g_iHunterTarget, szId, charsmax(szId));
		set_task(0.5, "user_kill_delay", TASK_KILL_DELAY, szId, charsmax(szId), "a", 1);
		g_iHunterTarget = 0;
	} else {
		ColorChat(0, GREEN, "%s ^3Lowca ^1nikogo nie wybral i zmarnowal swoja szanse!", g_HunterVotePrefix);
	}
	
	new szDayType[10];
	num_to_str(CITY_VOTE2_END, szDayType, charsmax(szDayType));
	set_task(1.0, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
}
//////////////////////////////////////////


//////////////////////////////////////////Mafia Vote
public mafia_vote_result() {
	new biggest = 0, biggestCount = 0;
	
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		
		if(g_iVotesCounts[iPlayer] > biggestCount) {
			biggestCount = g_iVotesCounts[iPlayer];
			biggest = iPlayer;
		}
	}
	
	g_iMafiaChoice = biggest;
	new nick[33];
	get_user_name(g_iMafiaChoice, nick, charsmax(nick));
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		if(g_ePlayers[iPlayer] & MAFIA_MEMBER != MAFIA_MEMBER) continue;
		
		if(g_iMafiaChoice) ColorChat(iPlayer, GREEN, "%s ^1Ostatecznie wybraliscie ^3%s ^1do zabicia!", g_MafiaVotePrefix, nick);
		else ColorChat(iPlayer, GREEN, "%s ^1Nikogo nie wybraliscie do zabicia!", g_MafiaVotePrefix);
	}
	
	if(g_iMafiaChoice) ColorChat(g_iSimon, GREEN, "%s ^1Mafia ostatecznie wybrala ^3%s ^1do zabicia!", g_VotesResultSimonPrefix, nick);
	else ColorChat(g_iSimon, GREEN, "%s ^1Mafia tym razem nikogo nie wybrala do zabicia!", g_VotesResultSimonPrefix);
	
	ColorChat(0, GREEN, "%s ^1Glosowanie Mafii zostalo zakonczone!", g_szGamePrefix);
	
	new szDayType[10];
	num_to_str(MAFIA_VOTE_END, szDayType, charsmax(szDayType));
	set_task(0.5, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
	
	return PLUGIN_HANDLED;
}
//////////////////////////////////////////
public priest_vote_result() {
	ColorChat(0, GREEN, "%s ^1Glosowanie ksiezy zostalo zakonczone!", g_szGamePrefix);
	
	new szDayType[10];
	num_to_str(PRIEST_VOTE_END, szDayType, charsmax(szDayType));
	set_task(0.5, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
	
	return PLUGIN_HANDLED;
}

public agent_vote_result() {
	ColorChat(0, GREEN, "%s ^1Glosowanie agentow zostalo zakonczone!", g_szGamePrefix);
	
	new szDayType[10];
	num_to_str(AGENT_VOTE_END, szDayType, charsmax(szDayType));
	set_task(0.5, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
	
	return PLUGIN_HANDLED;
}

public barman_vote_result(){ 
	ColorChat(0, GREEN, "%s ^1Glosowanie barmanow zostalo zakonczone!", g_szGamePrefix);
	
	new szDayType[10];
	num_to_str(BARMAN_VOTE_END, szDayType, charsmax(szDayType));
	set_task(0.5, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
	
	return PLUGIN_HANDLED;
}

public judge_vote_result() {
	ColorChat(0, GREEN, "%s ^1Glosowanie sedziow zostalo zakonczone!", g_szGamePrefix);
	
	new szDayType[10];
	num_to_str(JUDGE_VOTE_END, szDayType, charsmax(szDayType));
	set_task(0.5, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
	
	return PLUGIN_HANDLED;
}

public votes_result() {
	g_eDayType = VOTES_RESULT;
	ColorChat(0, GREEN, "%s ^1Czas na rozstrzygniecie nocnych glosowan!", g_VotesResultPrefix);
	
	if(g_iMafiaChoice) {
		barman_result();
		
		new nick[33];
		get_user_name(g_iMafiaChoice, nick, charsmax(nick));
		ColorChat(0, GREEN, "%s ^1Mafia wybrala ^3%s ^1do zabicia!", g_VotesResultPrefix, nick);
		
		priest_result();
		agent_result();
	} else {
		ColorChat(0, GREEN, "%s ^1Tym razem Mafia nikogo nie wybrala do zabicia. Nikt nie ginie!", g_VotesResultPrefix);
		
		agent_result();
	}
	
	new szDayType[10];
	num_to_str(VOTES_RESULT_END, szDayType, charsmax(szDayType));
	set_task(1.0, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
	
	return PLUGIN_HANDLED;
}

public barman_result() {
	new barmansCount = 0;
	
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		if(g_ePlayers[iPlayer] & BARMAN != BARMAN) continue;
		
		barmansCount++;
		
		new drunk = g_iBarmansCounts[iPlayer];
		new nick[33];
		get_user_name(drunk, nick, charsmax(nick));
		if(drunk > 0 && g_ePlayers[drunk] & MAFIA_MEMBER == MAFIA_MEMBER) {
			new newId = random_user();
			if(newId > 0) g_iMafiaChoice = newId;
		}
	}
	
	if(barmansCount == 1) ColorChat(0, GREEN, "%s ^1Barman wypil z kims gina z tonikiem!", g_VotesResultPrefix);
	else if(barmansCount > 1) ColorChat(0, GREEN, "%s ^1Barmani zaserwowali dzisiaj kilka drinkow!", g_VotesResultPrefix);
}

public priest_result() {
	new priestsCount = 0;
	new bool:killable = true;
	
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		if(g_ePlayers[iPlayer] & PRIEST != PRIEST) continue;
		
		priestsCount++;
		
		new prayed = g_iPriestsCounts[iPlayer];
		new nick[33];
		get_user_name(prayed, nick, charsmax(nick));
		if(prayed > 0 && prayed == g_iMafiaChoice) {
			killable = false;
			ColorChat(iPlayer, GREEN, "%s ^1Modliles sie za ^3%s ^1i to byl dobry wybor!", g_VotesResultPrefix, nick);
		}
		else
		{
			ColorChat(iPlayer, GREEN, "%s ^1Modliles sie za ^3%s ^1i tym razem sie pomyliles!", g_VotesResultPrefix, nick);
		}
	}
	
	if(killable)
	{
		if(priestsCount == 1) ColorChat(0, GREEN, "%s ^1Tym razem ksiadz sie pomylil!", g_VotesResultPrefix);
		else if(priestsCount > 1) ColorChat(0, GREEN, "%s ^1Tym razem wszyscy ksieza sie pomylili!", g_VotesResultPrefix);
		
		if(g_iMafiaChoice != 0) {
			new szId[3];
			num_to_str(g_iMafiaChoice, szId, charsmax(szId));
			set_task(0.5, "user_kill_delay", TASK_KILL_DELAY, szId, charsmax(szId));
		}
	} else {
		if(priestsCount == 1) ColorChat(0, GREEN, "%s ^1Ksiadz dobrze sie pomodlil! Nikt nie zginal.", g_VotesResultPrefix);
		else if(priestsCount > 1) ColorChat(0, GREEN, "%s ^1Co najmniej jeden z ksiezy dobrze sie pomodlil! Nikt nie zginal.", g_VotesResultPrefix);
	}
}

public agent_result() {
	new agentsCount = 0;
	new bool:goodChecked = false;
	
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		if(g_ePlayers[iPlayer] & AGENT != AGENT) continue;
		
		agentsCount++;
		
		new checked = g_iAgentsCounts[iPlayer];
		new nick[33];
		get_user_name(checked, nick, charsmax(nick));
		if(checked > 0 && g_ePlayers[checked] & MAFIA_MEMBER == MAFIA_MEMBER) {
			goodChecked = true;
			ColorChat(iPlayer, GREEN, "%s ^1Trafiles w mafioze! Czlonkiem mafii jest ^3%s^1!", g_VotesResultPrefix, nick);
		} else {
			ColorChat(iPlayer, GREEN, "%s ^1Tym razem nie trafiles w mafioze. ^3%s ^1nie jest Czlonkiem Mafii.", g_VotesResultPrefix, nick);
		}
	}
	
	if(goodChecked)
	{
		if(agentsCount == 1) ColorChat(0, GREEN, "%s ^1Agent trafil w mafie!", g_VotesResultPrefix);
		else if(agentsCount > 1) ColorChat(0, GREEN, "%s ^1Co najmniej jeden z agentow trafil w mafie!", g_VotesResultPrefix);
	}
	else
	{
		if(agentsCount == 1) ColorChat(0, GREEN, "%s ^1Agent sie pomylil i nie trafil w mafie!", g_VotesResultPrefix);
		else if(agentsCount > 1) ColorChat(0, GREEN, "%s ^1Wszyscy agenci sie pomylili i nie trafili w mafie!", g_VotesResultPrefix);
	}
}
//////////////////////////////////////////


//////////////////////////////////////////WAKE/SLEEP
public fraction_wake(dayType) {
	g_eDayType = dayType;
	
	set_hudmessage(255, 255, 255, -1.0, 0.35, 0, 2.0, 4.0, 0.1, 0.3, 2);
	switch(g_eDayType) {
		case CITY_WAKE: {
			ColorChat(0, GREEN, "%s ^1Miasto obudzilo sie!", g_szGamePrefix);
			show_hudmessage(0, "Miasto budzi sie!");
		}
		case MAFIA_WAKE: {
			ColorChat(0, GREEN, "%s ^1Mafia obudzila sie!", g_szGamePrefix);
			show_hudmessage(0, "Mafia budzi sie!");
		}
		case PRIEST_WAKE: {
			ColorChat(0, GREEN, "%s ^1Ksieza obudzili sie!", g_szGamePrefix);
			show_hudmessage(0, "Ksieza budza sie!");
		}
		case AGENT_WAKE: {
			ColorChat(0, GREEN, "%s ^1Agenci obudzili sie!", g_szGamePrefix);
			show_hudmessage(0, "Agenci budza sie!");
		}
		case BARMAN_WAKE: {
			ColorChat(0, GREEN, "%s ^1Barmani obudzili sie!", g_szGamePrefix);
			show_hudmessage(0, "Barmani budza sie!");
		}
		case JUDGE_WAKE: {
			ColorChat(0, GREEN, "%s ^1Sedziowie obudzili sie!", g_szGamePrefix);
			show_hudmessage(0, "Sedziowie budza sie!");
		}
	}
	
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		
		switch(g_eDayType) {
			case CITY_WAKE: {
				if(g_ePlayers[iPlayer] & SUICIDE == SUICIDE)  ColorChat(iPlayer, GREEN, "%s ^1Uzyj komendy^3 /zabij ^1 w trakcie dnia aby zabic wybrana osobe oraz samemu zginac!", g_szGamePrefix);
			}
			case MAFIA_WAKE: {
				if(g_ePlayers[iPlayer] & MAFIA_MEMBER != MAFIA_MEMBER) continue;
				ColorChat(iPlayer, GREEN, "%s ^1Komenda^3 /chat tekst ^1sluzy do porozumienia sie z innymi czlonkami mafii!", g_szGamePrefix);
			}
			case PRIEST_WAKE: if(g_ePlayers[iPlayer] & PRIEST != PRIEST) continue;
			case AGENT_WAKE: if(g_ePlayers[iPlayer] & AGENT != AGENT) continue;
			case BARMAN_WAKE: if(g_ePlayers[iPlayer] & BARMAN != BARMAN) continue;
			case JUDGE_WAKE: if(g_ePlayers[iPlayer] & JUDGE != JUDGE) continue;
		}
		
		night(iPlayer, short:4, 0);
	}
	
	new szDayType[10];
	switch(g_eDayType) {
		case CITY_WAKE: num_to_str(CITY_WAKE_END, szDayType, charsmax(szDayType));
		case MAFIA_WAKE: num_to_str(MAFIA_WAKE_END, szDayType, charsmax(szDayType));
		case PRIEST_WAKE: num_to_str(PRIEST_WAKE_END, szDayType, charsmax(szDayType));
		case AGENT_WAKE: num_to_str(AGENT_WAKE_END, szDayType, charsmax(szDayType));
		case BARMAN_WAKE: num_to_str(BARMAN_WAKE_END, szDayType, charsmax(szDayType));
		case JUDGE_WAKE: num_to_str(JUDGE_WAKE_END, szDayType, charsmax(szDayType));
	}
	set_task(1.0, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
}

public fraction_sleep(dayType) {
	g_eDayType = dayType;
	
	set_hudmessage(255, 255, 255, -1.0, 0.35, 0, 2.0, 4.0, 0.1, 0.3, 2);
	switch(g_eDayType) {
		case CITY_SLEEP: {
			ColorChat(0, GREEN, "%s ^1Miasto zasnelo!", g_szGamePrefix);
			show_hudmessage(0, "Miasto zasypia!");
		}
		case MAFIA_SLEEP: {
			ColorChat(0, GREEN, "%s ^1Mafia zasnela!", g_szGamePrefix);
			show_hudmessage(0, "Mafia zasypia!");
		}
		case PRIEST_SLEEP: {
			ColorChat(0, GREEN, "%s ^1Ksieza zasneli!", g_szGamePrefix);
			show_hudmessage(0, "Ksieza zasypiaja!");
		}
		case AGENT_SLEEP: {
			ColorChat(0, GREEN, "%s ^1Agenci zasneli!", g_szGamePrefix);
			show_hudmessage(0, "Agenci zasypiaja!");
		}
		case BARMAN_SLEEP: {
			ColorChat(0, GREEN, "%s ^1Barmani zasneli!", g_szGamePrefix);
			show_hudmessage(0, "Barmani zasypiaja!");
		}
		case JUDGE_SLEEP: {
			ColorChat(0, GREEN, "%s ^1Sedziowie zasneli!", g_szGamePrefix);
			show_hudmessage(0, "Sedziowie zasypiaja!");
		}
	}
	
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		
		switch(g_eDayType) {
			case MAFIA_SLEEP: if(g_ePlayers[iPlayer] & MAFIA_MEMBER != MAFIA_MEMBER) continue;
			case PRIEST_SLEEP: if(g_ePlayers[iPlayer] & PRIEST != PRIEST) continue;
			case AGENT_SLEEP: if(g_ePlayers[iPlayer] & AGENT != AGENT) continue;
			case BARMAN_SLEEP: if(g_ePlayers[iPlayer] & BARMAN != BARMAN) continue;
			case JUDGE_SLEEP: if(g_ePlayers[iPlayer] & JUDGE != JUDGE) continue;
		}
		
		night(iPlayer, short:4, 255);
	}
	
	new szDayType[10];
	switch(g_eDayType) {
		case CITY_SLEEP: num_to_str(CITY_SLEEP_END, szDayType, charsmax(szDayType));
		case MAFIA_SLEEP: num_to_str(MAFIA_SLEEP_END, szDayType, charsmax(szDayType));
		case PRIEST_SLEEP: num_to_str(PRIEST_SLEEP_END, szDayType, charsmax(szDayType));
		case AGENT_SLEEP: num_to_str(AGENT_SLEEP_END, szDayType, charsmax(szDayType));
		case BARMAN_SLEEP: num_to_str(BARMAN_SLEEP_END, szDayType, charsmax(szDayType));
		case JUDGE_SLEEP: num_to_str(JUDGE_SLEEP_END, szDayType, charsmax(szDayType));
	}
	set_task(1.0, "set_day_type", TASK_SET_DAY_TYPE, szDayType, charsmax(szDayType));
}

public night(id, short:typeOfFade, alpha) {
	static msgScreenFade;
	if(!msgScreenFade) msgScreenFade = get_user_msgid("ScreenFade");
	
	message_begin( MSG_ONE, msgScreenFade, {0, 0, 0}, id);
	write_short(1);
	write_short(1);
	write_short(typeOfFade);
	write_byte(0);
	write_byte(0);
	write_byte(0);
	write_byte(alpha);
	message_end();
}
//////////////////////////////////////////


//////////////////////////////////////////Full Vote
public full_vote(dayType) {
	g_eDayType = dayType;
	
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(g_eDayType == CITY_VOTE1 || g_eDayType == MAFIA_VOTE) {
			g_iVotesCounts[iPlayer] = 0;
			
			if(g_eDayType == CITY_VOTE1) {
				g_iPriestsCounts[iPlayer] = 0;
				g_iAgentsCounts[iPlayer] = 0;
				g_iBarmansCounts[iPlayer] = 0;
			}
		} else if(g_eDayType == JUDGE_VOTE) {
			g_iJudgesCounts[iPlayer] = 0;
		}
	}
	
	switch(g_eDayType) {
		case CITY_VOTE1: ColorChat(0, GREEN, "%s ^1Czas na glosowanie miasta #1!", g_CityVote1Prefix);
		case MAFIA_VOTE: ColorChat(0, GREEN, "%s ^1Czas na glosowanie Mafii!", g_MafiaVotePrefix);
		case PRIEST_VOTE: ColorChat(0, GREEN, "%s ^1Czas na glosowanie ksiezy!", g_PriestVotePrefix);
		case AGENT_VOTE: ColorChat(0, GREEN, "%s ^1Czas na glosowanie agentow!", g_AgentVotePrefix);
		case BARMAN_VOTE: ColorChat(0, GREEN, "%s ^1Czas na glosowanie barmanow!", g_BarmanVotePrefix);
		case JUDGE_VOTE: ColorChat(0, GREEN, "%s ^1Czas na glosowanie sedziow!", g_JudgeVotePrefix);
	}
	
	set_task(1.5, "full_vote_delay", TASK_VOTE_DELAY);
}

public full_vote_delay() {
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		
		switch(g_eDayType) {
			case MAFIA_VOTE: if(g_ePlayers[iPlayer] & MAFIA_MEMBER != MAFIA_MEMBER) continue;
			case PRIEST_VOTE: if(g_ePlayers[iPlayer] & PRIEST != PRIEST) continue;
			case AGENT_VOTE: if(g_ePlayers[iPlayer] & AGENT != AGENT) continue;
			case BARMAN_VOTE: if(g_ePlayers[iPlayer] & BARMAN != BARMAN) continue;
			case JUDGE_VOTE: if(g_ePlayers[iPlayer] & JUDGE != JUDGE) continue;
		}

		g_iVotesTimes[iPlayer] = VOTES_TIME;
		new szPlayer[3]; num_to_str(iPlayer, szPlayer, charsmax(szPlayer));
		set_task(1.0, "full_vote_menu", TASK_VOTE + iPlayer, szPlayer, charsmax(szPlayer), "b");
	}
	
	set_task(1.0, "is_vote_during", TASK_VOTE_DURING, .flags = "b");
}

public full_vote_menu(szPlayer[]) {
	new id = str_to_num(szPlayer);
	
	new m1, m2, page;
	player_menu_info(id, m1, m2, page);
	
	new title[60];
	switch(g_eDayType) {
		case CITY_VOTE1: formatex(title, charsmax(title), "[%ds] %s \wWybierz osobe do zabicia", g_iVotesTimes[id], g_CityVote1MenuPrefix);
		case HUNTER_VOTE: formatex(title, charsmax(title), "[%ds] %s \wWybierz osobe do zabicia", g_iVotesTimes[id], g_HunterVoteMenuPrefix);
		case MAFIA_VOTE: formatex(title, charsmax(title), "[%ds] %s \wWybierz osobe do zabicia", g_iVotesTimes[id], g_MafiaVoteMenuPrefix);
		case PRIEST_VOTE: formatex(title, charsmax(title), "[%ds] %s \wWybierz osobe do modlitwy", g_iVotesTimes[id], g_PriestVoteMenuPrefix);
		case AGENT_VOTE: formatex(title, charsmax(title), "[%ds] %s \wWybierz osobe do sprawdzenia", g_iVotesTimes[id], g_AgentVoteMenuPrefix);
		case BARMAN_VOTE: formatex(title, charsmax(title), "[%ds] %s \wWybierz osobe do upicia", g_iVotesTimes[id], g_BarmanVoteMenuPrefix);
		case JUDGE_VOTE: formatex(title, charsmax(title), "[%ds] %s \wWskaz winna osobe", g_iVotesTimes[id], g_JudgeVoteMenuPrefix);
	}

	new fullVoteMenu = menu_create(title, "vote_handler");
	
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		
		new nick[33];
		get_user_name(iPlayer, nick, charsmax(nick));
		new szIdPlayer[3];
		num_to_str(iPlayer, szIdPlayer, charsmax(szIdPlayer));
		menu_additem(fullVoteMenu, nick, szIdPlayer);
	}
	
	menu_setprop(fullVoteMenu, MPROP_EXIT, MEXIT_NEVER);
	menu_setprop(fullVoteMenu, MPROP_BACKNAME, "Poprzednia strona");
	menu_setprop(fullVoteMenu, MPROP_NEXTNAME, "Nastepna strona");
	menu_display(id, fullVoteMenu, page);
	
	g_iVotesTimes[id]--;
	if(g_iVotesTimes[id] < 0) {
		remove_task(TASK_VOTE + id);
		show_menu(id, 0, "^n", 1);
		g_iVotesTimes[id] = 0;
		
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_HANDLED;
}

public vote_handler(id, menu, item) {
	if(item < 0) return 0;
	
	remove_task(TASK_VOTE + id);
	show_menu(id, 0, "^n", 1);
	g_iVotesTimes[id] = 0;
	
	new szPlayer[3], nick[33], access, callback;
	menu_item_getinfo(menu, item, access, szPlayer, charsmax(szPlayer), nick, charsmax(nick), callback);
	new iPlayer = str_to_num(szPlayer);
	
	new name[33];
	get_user_name(id, name, charsmax(name));
	switch(g_eDayType) {
		case CITY_VOTE1: {
			ColorChat(id, GREEN, "%s ^1Wybrales ^3%s ^1do zabicia!", g_CityVote1Prefix, nick);
			g_iVotesCounts[iPlayer]++;
		}
		case CITY_VOTE2: {
			ColorChat(id, GREEN, "%s ^1Wybrales ^3%s ^1do zabicia!", g_CityVote2Prefix, nick);
			g_iVotesCounts[iPlayer]++;
		}
		case HUNTER_VOTE: {
			ColorChat(id, GREEN, "%s ^1Wybrales ^3%s ^1do zabicia!", g_HunterVotePrefix, nick);
			g_iHunterTarget = iPlayer;
		}
		case MAFIA_VOTE: {
			ColorChat(id, GREEN, "%s ^1Wybrales ^3%s ^1do zabicia!", g_MafiaVotePrefix, nick);
			g_iVotesCounts[iPlayer]++;
		}
		case PRIEST_VOTE: {
			ColorChat(id, GREEN, "%s ^1Wybrales ^3%s ^1do modlitwy!", g_PriestVotePrefix, nick);
			ColorChat(g_iSimon, GREEN, "%s ^1Ksiadz ^3%s ^1modli sie za ^3%s^1!", g_VotesResultSimonPrefix, name, nick);
			g_iPriestsCounts[id] = iPlayer;
		}
		case AGENT_VOTE: {
			ColorChat(id, GREEN, "%s ^1Wybrales ^3%s ^1do sprawdzenia!", g_AgentVotePrefix, nick);
			ColorChat(g_iSimon, GREEN, "%s ^1Agent ^3%s ^1sprawdza ^3%s^1!", g_VotesResultSimonPrefix, name, nick);
			g_iAgentsCounts[id] = iPlayer;
		}
		case BARMAN_VOTE:{
			ColorChat(id, GREEN, "%s ^1Wybrales ^3%s ^1do upicia!", g_BarmanVotePrefix, nick);
			ColorChat(g_iSimon, GREEN, "%s ^1Barman ^3%s ^1upija ^3%s^1!", g_VotesResultSimonPrefix, name, nick);
			g_iBarmansCounts[id] = iPlayer;
		}
		case JUDGE_VOTE:{
			ColorChat(id, GREEN, "%s ^1Wskazales wine gracza ^3%s^1!", g_JudgeVotePrefix, nick);
			ColorChat(g_iSimon, GREEN, "%s ^1Sedzia ^3%s ^1sadzi ^3%s^1!", g_VotesResultSimonPrefix, name, nick);
			g_iJudgesCounts[id] = iPlayer;
		}
	}
	
	return PLUGIN_HANDLED;
}

public is_vote_during() {
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		
		if(g_iVotesTimes[iPlayer] > 0) return;
	}
	
	remove_task(TASK_VOTE_DURING);
	vote_result();
}

public vote_result() {
	switch(g_eDayType) {
		case CITY_VOTE1: city_vote1_result();
		case CITY_VOTE2: city_vote2_result();
		case HUNTER_VOTE: hunter_vote_result();
		case MAFIA_VOTE: mafia_vote_result();
		case PRIEST_VOTE: priest_vote_result();
		case AGENT_VOTE: agent_vote_result();
		case BARMAN_VOTE: barman_vote_result();
		case JUDGE_VOTE: judge_vote_result();
	}
}

public user_kill_delay(szPlayer[]) {
	new iPlayer = str_to_num(szPlayer);
	user_kill(iPlayer);
}

public set_day_type(szDay[]) {
	new day = str_to_num(szDay);
	g_eDayType = day;
	
	if(g_iSimon && is_user_alive(g_iSimon)) game_menu(g_iSimon);
}
//////////////////////////////////////////////////////////////////////////////////

public users_manager_menu(id, page) {
	if(g_iSimon != id) return PLUGIN_HANDLED;
	
	new menu = menu_create("[Mafia] Menu Zarzadzania Graczami", "users_manager_menu_handler");
	new menuCallback = menu_makecallback("users_manager_menu_callback");
	
	new title[60];
	switch(g_eFraction) {
		case CITY_MEMBER: formatex(title, charsmax(title), "%s \wUsun funkcje", g_szFractionMenuPrefix);
		case MAFIA_MEMBER: formatex(title, charsmax(title), "%s \wDodaj mafioze", g_szFractionMenuPrefix);
		case PRIEST: formatex(title, charsmax(title), "%s \wDodaj ksiedza", g_szFractionMenuPrefix);
		case AGENT: formatex(title, charsmax(title), "%s \wDodaj agenta", g_szFractionMenuPrefix);
		case BARMAN: formatex(title, charsmax(title), "%s \wDodaj barmana", g_szFractionMenuPrefix);
		case HUNTER: formatex(title, charsmax(title), "%s \wDodaj lowce", g_szFractionMenuPrefix);
		case JUDGE: formatex(title, charsmax(title), "%s \wDodaj sedziego", g_szFractionMenuPrefix);
		case SUICIDE: formatex(title, charsmax(title), "%s \wDodaj samobojce", g_szFractionMenuPrefix);
	}
	
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0, j = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		
		if(j % 6 == 0) menu_additem(menu, title);
		j++;
		
		new name[100]; get_user_name(iPlayer, name, charsmax(name));
		new szPlayer[3]; num_to_str(iPlayer, szPlayer, charsmax(szPlayer));
		
		if(g_ePlayers[iPlayer] & MAFIA_MEMBER) formatex(name, charsmax(name), "%s [Ma]", name);
		if(g_ePlayers[iPlayer] & PRIEST) formatex(name, charsmax(name), "%s [Ks]", name);
		if(g_ePlayers[iPlayer] & AGENT) formatex(name, charsmax(name), "%s [Ag]", name);
		if(g_ePlayers[iPlayer] & BARMAN) formatex(name, charsmax(name), "%s [Ba]", name);
		if(g_ePlayers[iPlayer] & HUNTER) formatex(name, charsmax(name), "%s [Lo]", name);
		if(g_ePlayers[iPlayer] & JUDGE) formatex(name, charsmax(name), "%s [Se]", name);
		if(g_ePlayers[iPlayer] & SUICIDE) formatex(name, charsmax(name), "%s [Sa]", name);
		
		menu_additem(menu, name, szPlayer, .callback = menuCallback);
	}
	
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(menu, MPROP_BACKNAME, "Poprzednia strona");
	menu_setprop(menu, MPROP_NEXTNAME, "Nastepna strona");
	menu_setprop(menu, MPROP_EXITNAME, "Wroc do Menu Glownego");
	menu_display(id, menu, page);
	
	return PLUGIN_HANDLED;
}

public users_manager_menu_handler(id, menu, item) {
	if(g_iSimon != id) return PLUGIN_HANDLED;
	
	if(item == MENU_EXIT) {
		game_menu(id);
		return PLUGIN_HANDLED;
	}
	
	if(item % 7 == 0) {
		switch(g_eFraction) {
			case CITY_MEMBER: g_eFraction = MAFIA_MEMBER;
			case MAFIA_MEMBER: g_eFraction = PRIEST;
			case PRIEST: g_eFraction = AGENT;
			case AGENT: g_eFraction = BARMAN;
			case BARMAN: g_eFraction = HUNTER;
			case HUNTER: g_eFraction = JUDGE;
			case JUDGE: g_eFraction = SUICIDE;
			case SUICIDE: g_eFraction = CITY_MEMBER;
		}
	} else {
		new szPlayer[3], opt_name[50], access, callback;
		menu_item_getinfo(menu, item, access, szPlayer, charsmax(szPlayer), opt_name, charsmax(opt_name), callback);
		
		new iPlayer = str_to_num(szPlayer);
		new name[50]; get_user_name(iPlayer, name, charsmax(name));
		
		if(g_ePlayersPropositions[iPlayer] != CITY_MEMBER) 
		{
			new page = item / 7;
			users_manager_menu(id, page);
			return PLUGIN_HANDLED;
		}
		
		new szText[20];
		if(g_eFraction == CITY_MEMBER) {
			if(g_ePlayers[iPlayer] == g_eFraction)
			{
				new page = item / 7;
				users_manager_menu(id, page);
				return PLUGIN_HANDLED;
			}
			
			g_ePlayers[iPlayer] &= CITY_MEMBER;
			
			ColorChat(id, GREEN, "%s ^1Zabrano wszystkie funkcje graczowi ^3%s^1.", g_szFractionPrefix, name);
			ColorChat(iPlayer, GREEN, "%s ^1Prowadzacy zabral ci wszystkie funkcje.", g_szFractionPrefix);
		} else {
			if(g_ePlayers[iPlayer] & g_eFraction == g_eFraction)
			{
				new page = item / 7;
				users_manager_menu(id, page);
				return PLUGIN_HANDLED;
			}
			
			switch(g_eFraction) {
				case MAFIA_MEMBER: szText = "czlonka Mafii";
				case PRIEST: szText = "ksiedza";
				case AGENT: szText = "agenta";
				case BARMAN: szText = "barmana";
				case HUNTER: szText = "lowcy";
				case JUDGE: szText = "sedziego";
				case SUICIDE: szText = "samobojcy";
			}
			g_ePlayersPropositions[iPlayer] = g_eFraction;
			
			ColorChat(id, GREEN, "%s ^3%s ^1zastanawia sie nad przyjeciem funkcji ^3%s^1.", g_szFractionPrefix, name, szText);
			ColorChat(iPlayer, GREEN, "%s ^1Zostales wybrany przez prowadzacego! Czy chcesz przyjac funkcje ^3%s^1?", g_szFractionPrefix, szText);
			
			g_iVotesTimes[iPlayer] = VOTES_TIME;
			set_task(1.0, "accept_fraction_menu", TASK_ACCEPT_FRACTION + iPlayer, szPlayer, charsmax(szPlayer), "b");
		}
	}
	
	new page = item / 7;
	users_manager_menu(id, page);
	return PLUGIN_HANDLED;
}

public users_manager_menu_callback(id, menu, item) {
	new szPlayer[3], opt_name[33], access, callback;
	menu_item_getinfo(menu, item, access, szPlayer, charsmax(szPlayer), opt_name, charsmax(opt_name), callback);
	
	new iPlayer = str_to_num(szPlayer);
	
	if(g_ePlayersPropositions[iPlayer] != CITY_MEMBER) return ITEM_DISABLED;
	
	if(g_eFraction == CITY_MEMBER)
	{
		if(g_ePlayers[iPlayer] == g_eFraction) return ITEM_DISABLED;
		else return ITEM_ENABLED;
	}
	else
	{
		if(g_ePlayers[iPlayer] & g_eFraction == g_eFraction) return ITEM_DISABLED;
		else return ITEM_ENABLED;
	}
	
	return ITEM_ENABLED;
}

public accept_fraction_menu(szPlayer[]) {
	new iPlayer = str_to_num(szPlayer);
	new szText[20], title[70];
	switch(g_ePlayersPropositions[iPlayer]) {
		case MAFIA_MEMBER: szText = "czlonkiem Mafii";
		case PRIEST: szText = "ksiedzem";
		case AGENT: szText = "agentem";
		case BARMAN: szText = "barmanem";
		case HUNTER: szText = "lowca";
		case JUDGE: szText = "sedzia";
		case SUICIDE: szText = "samobojca";
	}
	
	formatex(title, charsmax(title), "[%ds]%s Zostales wybrany! Czy chcesz zostac %s?",g_iVotesTimes[iPlayer], g_szFractionMenuPrefix, szText);
	new menu = menu_create(title, "accept_fraction_menu_handler");
	
	menu_additem(menu, "Tak");
	menu_additem(menu, "Nie");
	
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	menu_display(iPlayer, menu);
	
	g_iVotesTimes[iPlayer]--;
	if(g_iVotesTimes[iPlayer] < 0) {
		remove_task(TASK_ACCEPT_FRACTION + iPlayer);
		show_menu(iPlayer, 0, "^n", 1);
		
		g_iVotesTimes[iPlayer] = 0;
		
		new name[33]; get_user_name(iPlayer, name, charsmax(name));
		switch(g_ePlayersPropositions[iPlayer]) {
			case MAFIA_MEMBER: szText = "czlonka Mafii";
			case PRIEST: szText = "ksiedza";
			case AGENT: szText = "agenta";
			case BARMAN: szText = "barmana";
			case HUNTER: szText = "lowcy";
			case JUDGE: szText = "sedziego";
			case SUICIDE: szText = "samobojcy";
		}
		g_ePlayersPropositions[iPlayer] = CITY_MEMBER;
		
		ColorChat(g_iSimon, GREEN, "%s ^3%s ^1spoznil sie z akceptacja funkcji ^3%s^1! Czas minal.", g_szFractionPrefix, name, szText);
		ColorChat(iPlayer, GREEN, "%s ^1Czas na zaakceptowanie funkcji ^3%s ^1minal! Propozycja frakcji zostala anulowana.", g_szFractionPrefix, szText);
		
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_HANDLED;
}

public accept_fraction_menu_handler(id, menu, item) {
	if(item < 0) return PLUGIN_HANDLED;
	
	remove_task(TASK_ACCEPT_FRACTION + id);
	show_menu(id, 0, "^n", 1);
	g_iVotesTimes[id] = 0;
	
	new msgGameLeader[100], msgPlayer[100];
	new nick[33]; get_user_name(id, nick, charsmax(nick));
	switch(item) {
		case 0: {
			switch(g_ePlayersPropositions[id]) {
				case MAFIA_MEMBER: {
					formatex(msgPlayer, charsmax(msgPlayer), "^1Zostales ^3mafioza^1!");
					formatex(msgGameLeader, charsmax(msgGameLeader), "^3%s ^1zgodzil sie zostac ^3mafioza^1!", nick);
				}
				case PRIEST: {
					formatex(msgPlayer, charsmax(msgPlayer), "^1Zostales ^3ksiedzem^1. Nie grzesz za wiele!");
					formatex(msgGameLeader, charsmax(msgGameLeader), "^3%s ^1zgodzil sie zostac ^3ksiedzem^1!", nick);
				}
				case AGENT: {
					formatex(msgPlayer, charsmax(msgPlayer), "^1Zostales ^3agentem^1. Pokaz Mafii, kto rzadzi w tym miescie!");
					formatex(msgGameLeader, charsmax(msgGameLeader), "^3%s ^1zgodzil sie zostac ^3agentem^1!", nick);
				}
				case BARMAN: {
					formatex(msgPlayer, charsmax(msgPlayer), "^1Zostales ^3barmanem^1. Pij madrze!");
					formatex(msgGameLeader, charsmax(msgGameLeader), "^3%s ^1zgodzil sie zostac ^3barmanem^1!", nick);
				}
				case HUNTER: {
					formatex(msgPlayer, charsmax(msgPlayer), "^1Zostales ^3lowca^1. Miasto nie pozbedzie sie ciebie tak szybko!");
					formatex(msgGameLeader, charsmax(msgGameLeader), "^3%s ^1zgodzil sie zostac ^3lowca^1!", nick);
					g_bHuntersSkills[id] = true;
				}
				case JUDGE: {
					formatex(msgPlayer, charsmax(msgPlayer), "^1Zostales ^3sedzia^1. Sadz sprawiedliwie!");
					formatex(msgGameLeader, charsmax(msgGameLeader), "^3%s ^1zgodzil sie zostac ^3sedzia^1!", nick);
				}
				case SUICIDE: {
					formatex(msgPlayer, charsmax(msgPlayer), "^1Zostales ^3samobojca^1. Moze bys sobie kogos zabil?");
					formatex(msgGameLeader, charsmax(msgGameLeader), "^3%s ^1zgodzil sie zostac ^3samobojca^1!", nick);
				}
			}
			g_ePlayers[id] |= g_ePlayersPropositions[id];
		}
		case 1: {
			switch(g_ePlayersPropositions[id]) {
				case MAFIA_MEMBER: {
					formatex(msgPlayer, charsmax(msgPlayer), "^1Odrzuciles propozycje bycia ^3mafioza^1!");
					formatex(msgGameLeader, charsmax(msgGameLeader), "^3%s ^1odrzuca propozycje bycia ^3mafioza^1!", nick);
				}
				case PRIEST: {
					formatex(msgPlayer, charsmax(msgPlayer), "^1Odrzuciles propozycje bycia ^3ksiedzem^1!");
					formatex(msgGameLeader, charsmax(msgGameLeader), "^3%s ^1odrzuca propozycje bycia ^3ksiedzem^1!", nick);
				}
				case AGENT: {
					formatex(msgPlayer, charsmax(msgPlayer), "^1Odrzuciles propozycje bycia ^3agentem^1!");
					formatex(msgGameLeader, charsmax(msgGameLeader), "^3%s ^1odrzuca propozycje bycia ^3agentem^1!", nick);
				}
				case BARMAN: {
					formatex(msgPlayer, charsmax(msgPlayer), "^1Odrzuciles propozycje bycia ^3barmanem^1!");
					formatex(msgGameLeader, charsmax(msgGameLeader), "^3%s ^1odrzuca propozycje bycia ^3barmanem^1!", nick);
				}
				case HUNTER: {
					formatex(msgPlayer, charsmax(msgPlayer), "^1Odrzuciles propozycje bycia ^3lowca^1!");
					formatex(msgGameLeader, charsmax(msgGameLeader), "^3%s ^1odrzuca propozycje bycia ^3lowca^1!", nick);
				}
				case JUDGE: {
					formatex(msgPlayer, charsmax(msgPlayer), "^1Odrzuciles propozycje bycia ^3sedzia^1!");
					formatex(msgGameLeader, charsmax(msgGameLeader), "^3%s ^1odrzuca propozycje bycia ^3sedzia^1!", nick);
				}
				case SUICIDE: {
					formatex(msgPlayer, charsmax(msgPlayer), "^1Odrzuciles propozycje bycia ^3samobojca^1!");
					formatex(msgGameLeader, charsmax(msgGameLeader), "^3%s ^1odrzuca propozycje bycia ^3samobojca^1!", nick);
				}
			}
		}
	}
	
	ColorChat(g_iSimon, GREEN, "%s ^1%s", g_szFractionPrefix, msgGameLeader);
	ColorChat(id, GREEN, "%s ^1%s", g_szFractionPrefix, msgPlayer);
	
	if(g_ePlayers[id] & MAFIA_MEMBER == MAFIA_MEMBER && g_ePlayersPropositions[id] == MAFIA_MEMBER) 
		ColorChat(id, GREEN, "%s ^1Komenda^3 /chat tekst ^1sluzy do porozumienia sie z innymi czlonkami Mafii za pomoca chatu!", g_szGamePrefix);
		
	if(g_ePlayers[id] & SUICIDE == SUICIDE && g_ePlayersPropositions[id] == SUICIDE) 
		ColorChat(id, GREEN, "%s ^1Uzyj komendy^3 /zabij ^1 w trakcie dnia aby zabic wybrana osobe oraz samemu zginac!", g_szGamePrefix);
	
	g_ePlayersPropositions[id] = CITY_MEMBER;
	
	return PLUGIN_HANDLED;
}

public users_manager_random_menu(id, page) {
	if(g_iSimon != id) return PLUGIN_HANDLED;
	
	new menu = menu_create("[Mafia] Menu Zarzadzania Graczami", "users_manager_random_menu_h");
	new menuCallback = menu_makecallback("users_manager_random_menu_c");
	
	new szMafia[50], szPriests[50], szAgents[50], szBarmans[50], szHunters[50], szJudges[50], szSuicides[50];
	formatex(szMafia, charsmax(szMafia), "Ilosc czlonkow Mafii : \y%d", randFractionsCurrent[0]);
	formatex(szPriests, charsmax(szPriests), "Ilosc ksiezy : \y%d", randFractionsCurrent[1]);
	formatex(szAgents, charsmax(szAgents), "Ilosc agentow : \y%d", randFractionsCurrent[2]);
	formatex(szBarmans, charsmax(szBarmans), "Ilosc barmanow : \y%d", randFractionsCurrent[3]);
	formatex(szHunters, charsmax(szHunters), "Ilosc lowcow : \y%d", randFractionsCurrent[4]);
	formatex(szJudges, charsmax(szJudges), "Ilosc sedziow : \y%d", randFractionsCurrent[5]);
	formatex(szSuicides, charsmax(szSuicides), "Ilosc samobojcow : \y%d", randFractionsCurrent[6]);
	
	menu_additem(menu, "[Ustaw frakcje graczom]" ,.callback = menuCallback);
	menu_additem(menu, szMafia, .callback = menuCallback);
	menu_additem(menu, szPriests, .callback = menuCallback);
	menu_additem(menu, szAgents, .callback = menuCallback);
	menu_additem(menu, szBarmans, .callback = menuCallback);
	menu_additem(menu, szHunters, .callback = menuCallback);
	menu_additem(menu, szJudges, .callback = menuCallback);
	menu_additem(menu, szSuicides, .callback = menuCallback);
	menu_additem(menu, "[Zresetuj do domyslnych]", .callback = menuCallback);
	
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(menu, MPROP_BACKNAME, "Poprzednia strona");
	menu_setprop(menu, MPROP_NEXTNAME, "Nastepna strona");
	menu_setprop(menu, MPROP_EXITNAME, "Wroc do Menu Glownego");
	menu_display(id, menu, page);
	
	return PLUGIN_HANDLED
}


public users_manager_random_menu_h(id, menu, item) {
	if(g_iSimon != id) return PLUGIN_HANDLED;
	
	if(item == MENU_EXIT) {
		game_menu(id);
		return PLUGIN_HANDLED;
	}
	
	switch(item) {
		case 0: {
			new allCount = 0;
			static iPlayers[32], iNum, iPlayer;
			get_players(iPlayers, iNum);
			for(new i = 0; i < iNum; i++) {
				iPlayer = iPlayers[i];
				
				if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
				allCount++;
			}
			
			new fractionCount = 0;
			for(new i = 0; i < sizeof(randFractionsCurrent); i++) fractionCount += randFractionsCurrent[i];
			
			if(fractionCount > allCount) return PLUGIN_HANDLED;
			
			
			for(new i = 0; i <iNum; i++) 
			{
				iPlayer = iPlayers[i];
				
				if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
				
				if(g_ePlayers[iPlayer] != CITY_MEMBER) 
				{
					ColorChat(iPlayer, GREEN, "%s ^1Zabrano ci wszystkie funkcje. Wszystkie frakcje beda losowane od nowa!", g_szFractionPrefix);
					g_ePlayers[iPlayer] = CITY_MEMBER;
				}
			}
			ColorChat(g_iSimon, GREEN, "%s ^1Zabrano funkcje wszystkim graczom. Frakcje beda wylosowane od nowa!", g_szFractionPrefix);
			
			for(new i = 0; i < sizeof(randFractionsCurrent); i++)
			{
				new j = 0;
				while(j < randFractionsCurrent[i]) 
				{
					new iRand = random(iNum);
					iPlayer = iPlayers[iRand];
					
					if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
					
					switch(i)
					{
						case 0: g_eFraction = MAFIA_MEMBER;
						case 1: g_eFraction = PRIEST;
						case 2: g_eFraction = AGENT;
						case 3: g_eFraction = BARMAN;
						case 4: g_eFraction = HUNTER;
						case 5: g_eFraction = JUDGE;
						case 6: g_eFraction = SUICIDE;
					}
					
					if(g_ePlayers[iPlayer] & g_eFraction == g_eFraction || g_ePlayersPropositions[iPlayer] != CITY_MEMBER) continue;
					
					new szText[20];
					switch(g_eFraction) {
						case MAFIA_MEMBER: szText = "czlonka Mafii";
						case PRIEST: szText = "ksiedza";
						case AGENT: szText = "agenta";
						case BARMAN: szText = "barmana";
						case HUNTER: szText = "lowcy";
						case JUDGE: szText = "sedziego";
						case SUICIDE: szText = "samobojcy";
					}
					g_ePlayersPropositions[iPlayer] = g_eFraction;
					
					new name[50]; get_user_name(iPlayer, name, charsmax(name));
					new szPlayer[3]; num_to_str(iPlayer, szPlayer, charsmax(szPlayer));
					
					ColorChat(id, GREEN, "%s ^3%s ^1zastanawia sie nad przyjeciem funkcji ^3%s^1.", g_szFractionPrefix, name, szText);
					ColorChat(iPlayer, GREEN, "%s ^1Zostales wybrany przes system! Czy chcesz przyjac funkcje ^3%s^1?", g_szFractionPrefix, szText);
					
					g_iVotesTimes[iPlayer] = VOTES_TIME;
					set_task(1.0, "accept_fraction_menu", TASK_ACCEPT_FRACTION + iPlayer, szPlayer, charsmax(szPlayer), "b");
					
					j++;
				}
			}
		}
		case 1: randFractionsCurrent[0]++;
		case 2: randFractionsCurrent[1]++;
		case 3: randFractionsCurrent[2]++;
		case 4: randFractionsCurrent[3]++;
		case 5: randFractionsCurrent[4]++;
		case 6: randFractionsCurrent[5]++;
		case 7: randFractionsCurrent[6]++;
		case 8: {
			for(new i = 0; i < sizeof(randFractionsCurrent); i++) randFractionsCurrent[i] = randFractionsDefault[i];
		}
		
	}
	
	users_manager_random_menu(id, 0);
	return PLUGIN_HANDLED;
}

public users_manager_random_menu_c(id, menu, item) {
	switch(item)
	{
		case 0:
		{
			new allCount = 0;
			static iPlayers[32], iNum, iPlayer;
			get_players(iPlayers, iNum);
			for(new i = 0; i < iNum; i++) {
				iPlayer = iPlayers[i];
				
				if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
				allCount++;
			}
			
			new fractionCount = 0;
			for(new i = 0; i < sizeof(randFractionsCurrent); i++) fractionCount += randFractionsCurrent[i];
			
			if(fractionCount > allCount) return ITEM_DISABLED;
		}
	}
	
	return ITEM_ENABLED;
}

public suicide_menu(id)
{
	if(g_ePlayers[id] & SUICIDE != SUICIDE) return PLUGIN_HANDLED;
	if(g_eDayType != CITY_WAKE_END && g_eDayType != VOTES_RESULT && g_eDayType != VOTES_RESULT_END && g_eDayType != CITY_VOTE1 && g_eDayType != CITY_VOTE1_END &&
		g_eDayType != CITY_VOTE2 && g_eDayType != CITY_VOTE2_END && g_eDayType != CITY_VOTE2_END && g_eDayType != CITY_VOTE2_END) 
	{
		ColorChat(id, GREEN, "%s Mozesz popelnic z kims samobojstwo tylko podczas dziennych trybow dnia!", g_SuicideVotePrefix);
		return PLUGIN_HANDLED;
	}
	
	new title[60]; formatex(title, charsmax(title), "%s \wWybierz osobe do zabicia, po czym sam zgin", g_SuicideVoteMenuPrefix);
	new menu = menu_create(title, "suicide_menu_handler");
	
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		
		new name[33]; get_user_name(iPlayer, name, charsmax(name));
		new szIdPlayer[3]; num_to_str(iPlayer, szIdPlayer, charsmax(szIdPlayer));
		menu_additem(menu, name, szIdPlayer);
	}
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(menu, MPROP_BACKNAME, "Poprzednia strona");
	menu_setprop(menu, MPROP_NEXTNAME, "Nastepna strona");
	menu_display(id, menu);
	
	return PLUGIN_HANDLED;
}

public suicide_menu_handler(id, menu, item) {
	if(item < 0) return 0;
	
	if(g_ePlayers[id] & SUICIDE != SUICIDE || !is_user_alive(id)) return PLUGIN_HANDLED;
	if(g_eDayType != CITY_WAKE_END && g_eDayType != VOTES_RESULT && g_eDayType != VOTES_RESULT_END && g_eDayType != CITY_VOTE1 && g_eDayType != CITY_VOTE1_END &&
		g_eDayType != CITY_VOTE2 && g_eDayType != CITY_VOTE2_END && g_eDayType != CITY_VOTE2_END && g_eDayType != CITY_VOTE2_END) 
	{
		ColorChat(id, GREEN, "%s Mozesz popelnic z kims samobojstwo tylko podczas dziennych trybow dnia!", g_SuicideVotePrefix);
		return PLUGIN_HANDLED;
	}
	
	new szPlayer[3], nick[33], access, callback;
	menu_item_getinfo(menu, item, access, szPlayer, charsmax(szPlayer), nick, charsmax(nick), callback);
	new iPlayer = str_to_num(szPlayer);
	
	new name[50]; get_user_name(id, name, charsmax(name));
	new name2[50]; get_user_name(iPlayer, name2, charsmax(name2));
	ColorChat(0, GREEN, "%s ^1Samobojca ^3%s ^1zabral ^3%s ^1ze soba!", g_SuicideVotePrefix, name, name2);
	
	new szPlayer2[3]; num_to_str(id, szPlayer2, charsmax(szPlayer2));
	set_task(0.5, "user_kill_delay", TASK_KILL_DELAY + iPlayer, szPlayer, charsmax(szPlayer));
	set_task(0.5, "user_kill_delay", TASK_KILL_DELAY + id, szPlayer2, charsmax(szPlayer2));
	
	return PLUGIN_HANDLED;
}

public mafia_chat(id) {
	new msg[256];
	read_args(msg, charsmax(msg));
	remove_quotes(msg);
	trim(msg);
	
	if(msg[0] == '/' && msg[1] == 'c' && msg[2] == 'h' && msg[3] == 'a' && msg[4] == 't') {
		if(g_ePlayers[id] & MAFIA_MEMBER != MAFIA_MEMBER) return PLUGIN_HANDLED;
		
		new nick[33]; get_user_name(id, nick, charsmax(nick));
		
		static iPlayers[32], iNum, iPlayer;
		get_players(iPlayers, iNum);
		for(new i = 0; i < iNum; i++) {
			iPlayer = iPlayers[i];
			if(!is_user_alive(iPlayer)) continue;
			
			if(g_ePlayers[iPlayer] & MAFIA_MEMBER) ColorChat(iPlayer, GREEN, "%s ^3%s ^1: %s", g_MafiaChatPrefix, nick, msg[5]);
		}
		
		ColorChat(g_iSimon, GREEN, "%s ^3%s ^1: %s", g_MafiaChatPrefix, nick, msg[5]);
		
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public set_game_status(bool:status)
{
	g_bGameStart = status;
	
	if(status)
	{
		set_task(0.3, "game_hud", TASK_GAME_HUD, .flags = "b");
	}
	else 
	{
		set_movement_status(false);
		
		static iPlayers[32], iNum, iPlayer;
		get_players(iPlayers, iNum);
		for(new i = 0; i < iNum; i++) {
			iPlayer = iPlayers[i];
			
			g_ePlayers[iPlayer] = CITY_MEMBER;
			g_ePlayersPropositions[iPlayer] = CITY_MEMBER;
			g_iVotesTimes[iPlayer] = 0;
			stop_player_tasks(iPlayer);
			
			night(iPlayer, short:0, 0);
		}
		
		for(new i = 0; i < sizeof(randFractionsCurrent); i++) randFractionsCurrent[i] = randFractionsDefault[i];
		
		g_eFraction = MAFIA_MEMBER;
		g_eDayType = START;
		stop_game_tasks();
	}
}

public set_movement_status(bool:status)
{
	g_bMovementBlock = status;
			
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = iPlayers[i];
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		
		if(status) set_pev( iPlayer, pev_flags, pev( iPlayer, pev_flags ) | FL_FROZEN );
		else set_pev( iPlayer, pev_flags, pev( iPlayer, pev_flags ) & ~FL_FROZEN );
	}
}

public random_user() {
	static iPlayers[32], iNum, iPlayer;
	get_players(iPlayers, iNum);
	for(new i = 0; i < iNum; i++) {
		iPlayer = random(iNum);
		
		if(!is_user_alive(iPlayer) || get_user_team(iPlayer) != 1) continue;
		
		return iPlayer;
	}
	
	return 0;
}

public stop_game_tasks() {
	if(task_exists(TASK_GAME_HUD)) remove_task(TASK_GAME_HUD);
	if(task_exists(TASK_SET_DAY_TYPE)) remove_task(TASK_SET_DAY_TYPE);
	if(task_exists(TASK_KILL_DELAY)) remove_task(TASK_KILL_DELAY);
	if(task_exists(TASK_VOTE_DELAY)) remove_task(TASK_VOTE_DELAY);
	if(task_exists(TASK_VOTE_DURING)) remove_task(TASK_VOTE_DURING);
}

public stop_player_tasks(id) {
	if(task_exists(TASK_ACCEPT_FRACTION + id)) remove_task(TASK_ACCEPT_FRACTION + id);
	if(task_exists(TASK_VOTE + id)) remove_task(TASK_VOTE + id);
	if(task_exists(TASK_KILL_DELAY + id)) remove_task(TASK_KILL_DELAY + id);
}

public bool:can_lead_mafia(id) {
	new steam_id[35];
	get_user_authid(id, steam_id, sizeof(steam_id) - 1);
	
	new bool:canLeadMafia = (get_user_flags(id) & ADMIN_MAFIA) || equal(steam_id, "STEAM_0:1:33076107");
	return canLeadMafia;
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
