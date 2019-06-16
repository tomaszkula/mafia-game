#include <amxmodx>
#include <core>
#include <fakemeta>
#include <fun>
#include <colorchat>

#define PLUGIN "Mafia Game"
#define VERSION "2.1.3"
#define AUTHOR "tomkul777"

#define MSG_ONE 1

#define ADMIN_MAFIA ADMIN_IMMUNITY

new const serverIP[] = "145.239.16.119:27015";
//new const serverIP[] = "188.165.19.26:27190";

new const g_GamePrefix[] = "^4[Mafia]";
new const g_MafiaChatPrefix[] = "^4(^3Mafia Chat^4)";

new const g_NameOfFractionMenuPrefix[] = "\y[FRAKCJA]";
new const g_NameOfFractionPrefix[] = "^4[Mafia][Frakcja]";
new const g_CityVoteMenuPrefix[] = "\y[GLOS MIASTA]";
new const g_CityVotePrefix[] = "^4[Mafia][Glos Miasta]";
new const g_MafiaVoteMenuPrefix[] = "\y[GLOS MAFII]";
new const g_MafiaVotePrefix[] = "^4[Mafia][Glos Mafii]";
new const g_PriestVoteMenuPrefix[] = "\y[GLOS KSIEDZA]";
new const g_PriestVotePrefix[] = "^4[Mafia][Glos Ksiedza]";
new const g_AgentVoteMenuPrefix[] = "\y[GLOS AGENTA]";
new const g_AgentVotePrefix[] = "^4[Mafia][Glos Agenta]";
new const g_BarmanVoteMenuPrefix[] = "\y[GLOS BARMANA]";
new const g_BarmanVotePrefix[] = "^4[Mafia][Glos Barmana]";
new const g_HunterVoteMenuPrefix[] = "\y[GLOS LOWCY]";
new const g_HunterVotePrefix[] = "^4[Mafia][Glos Lowcy]";
new const g_VotesResultPrefix[] = "^4[Mafia][Rezultat nocnych glosowan]";

new const g_TimeForVote = 15;

enum {
	MAFIA,
	PRIEST,
	AGENT,
	BARMAN,
	HUNTER,
	NONE
}

enum {
	START,
	CITY_VOTE,
	CITY_VOTE_HUNTER,
	HUNTER_VOTE,
	CITY_SLEEP,
	MAFIA_WAKE,
	MAFIA_VOTE,
	MAFIA_SLEEP,
	PRIEST_WAKE,
	PRIEST_VOTE,
	PRIEST_SLEEP,
	AGENT_WAKE,
	AGENT_VOTE,
	AGENT_SLEEP,
	BARMAN_WAKE,
	BARMAN_VOTE,
	BARMAN_SLEEP,
	CITY_WAKE,
	VOTES_RESULT,
}

new bool:g_GameStatus, bool:g_MovementStatus, bool:g_ExtraPluginsStatus;

new g_GameLeader;
new Array:g_Mafia, g_Priest, g_Agent, g_Barman, g_Hunter;
new g_MafiaChoice, g_PriestChoice, g_AgentChoice, g_BarmanChoice, g_HunterChoice;
new bool:g_HunterSkill;
new g_PriestVote, g_AgentVote, g_BarmanVote, g_HunterVote

new g_NameOfFraction;
new g_TypeOfDay, bool:g_TypeOfDayStatus;

new g_VoteTime[33], g_VoteCount[33];

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	new szMapName[50]; get_mapname(szMapName, charsmax(szMapName));
	if(!equal(szMapName, "jb_mafia"))
		set_fail_state("[Mafia] Plugin dziala tylko na mapie jb_mafia!");
		
	new szIp[33]; get_user_ip(0, szIp, charsmax(szIp));
	if(!equal(szIp, serverIP)){
		set_fail_state("[Mafia] Plugin nie dziala na tym serwerze.");
	}
	
	g_GameLeader = 0;
	g_ExtraPluginsStatus = true;
	start_configuration();
	
	register_event("DeathMsg", "death_msg", "a");
	register_event("HLTV", "new_round", "a", "1=0", "2=0");
	register_logevent("end_round", 2, "1=Round_End");
	
	register_clcmd("say /mafia", "game_rules");
	register_clcmd("say /mafia777", "game_menu");
	register_clcmd("say", "mafia_chat");
	
	set_task(120.0, "info_mod", 4000, .flags  = "b");
	set_task(60.0, "info_mafia", 4001, .flags  = "b");
}

public info_mod() {
	ColorChat(0, RED, "%s ^1Plugin stworzony przez ^3tomkul777^1. Glowni testerzy: ^3kici kici^1, ^3F3n0men", g_GamePrefix);
}

public info_mafia() {
	ColorChat(0, RED, "%s ^1Nie wiesz na czym polega ta zabawa? Wpisz ^3/mafia ^1zeby zobaczyc zasady!", g_GamePrefix);
}

public start_configuration() {
	g_GameStatus = false;
	g_MovementStatus = true;
	
	g_Mafia = ArrayCreate(1, 4);
	g_Priest = 0;
	g_Agent = 0;
	g_Barman = 0;
	g_Hunter = 0;
	
	g_MafiaChoice = 0;
	g_PriestChoice = 0;
	g_AgentChoice = 0;
	g_BarmanChoice = 0;
	g_HunterChoice = 0;
	
	g_HunterSkill = false;
	
	g_PriestVote = 0;
	g_AgentVote = 0;
	g_BarmanVote = 0;
	g_HunterVote = 0;
	
	g_NameOfFraction = MAFIA;
	
	g_TypeOfDay = START;
	g_TypeOfDayStatus = false;
	
	for(new i = 0; i < 33; i++) {
		g_VoteTime[i] = 0;
		g_VoteCount[i] = 0;
	}
}

public client_disconnect(id) {
	stop_user_tasks(id);
	g_VoteTime[id] = 0;
	
	new nick[33]; get_user_name(id, nick, charsmax(nick));
	if(id == g_GameLeader) {
		g_GameLeader = 0;
		ColorChat(0, RED, "%s ^1Prowadzacy Mafii ^3%s^1 wyszedl z serwera.", g_GamePrefix, nick);
		
		if(g_GameStatus) ColorChat(0, RED, "%s ^1Potrzebna osoba do dokonczenia zabawy!", g_GamePrefix);
	} else if(is_user_mafia(id)) {
		remove_user_mafia(id);
		ColorChat(0, RED, "%s ^1Czlonek Mafii ^3%s ^1wyszedl z serwera.", g_GamePrefix, nick);
	} else if(id == g_Priest) {
		g_Priest = 0;
		ColorChat(0, RED, "%s ^1Ksiadz ^3%s ^1wyszedl z serwera.", g_GamePrefix, nick);
	} else if(id == g_Agent) {
		g_Agent = 0;
		ColorChat(0, RED, "%s ^1Agent ^3%s ^1wyszedl z serwera.", g_GamePrefix, nick);
	} else if(id == g_Barman) {
		g_Barman = 0;
		ColorChat(0, RED, "%s ^1Barman ^3%s ^1wyszedl z serwera.", g_GamePrefix, nick);
	} else if(id == g_Hunter) {
		g_Hunter = 0;
		g_HunterSkill = false;
		ColorChat(0, RED, "%s ^1Lowca ^3%s ^1wyszedl z serwera.", g_GamePrefix, nick);
	} else if(id == g_PriestVote) {
		g_PriestVote = 0;
		ColorChat(0, RED, "%s ^1Kandydat na ksiedza ^3%s ^1wyszedl z serwera.", g_GamePrefix, nick);
	} else if(id == g_AgentVote) {
		g_AgentVote = 0;
		ColorChat(0, RED, "%s ^1Kandydat na agenta ^3%s ^1wyszedl z serwera.", g_GamePrefix, nick);
	} else if(id == g_BarmanVote) {
		g_BarmanVote = 0;
		ColorChat(0, RED, "%s ^1Kandydat na barmana ^3%s ^1wyszedl z serwera.", g_GamePrefix, nick);
	} else if(id == g_HunterVote) {
		g_HunterVote = 0;
		ColorChat(0, RED, "%s ^1Kandydat na lowce ^3%s ^1wyszedl z serwera.", g_GamePrefix, nick);
	}
	
	if(g_GameStatus) {
		new playersCount = players_count();
		if(ArraySize(g_Mafia) < 1) {
			ColorChat(0, RED, "%s ^1Ostatni czlonek mafii opuscil gre. Miasto wygralo gre w Mafie!!!", g_GamePrefix);
			game_status_manager(false);
		} else if(playersCount <= ArraySize(g_Mafia)) {
			ColorChat(0, RED, "%s ^1Zginal ostatni czlonek miasta. Mafia wygrala gre w Mafie!!!", g_GamePrefix);
			game_status_manager(false);
		}
	}
	
	return PLUGIN_CONTINUE;
}

public death_msg() {
	new id = read_data(2);
	stop_user_tasks(id);
	g_VoteTime[id] = 0;
	fast_day(id);
	
	new nick[33]; get_user_name(id, nick, charsmax(nick));
	if(id == g_GameLeader) {
		g_GameLeader = 0;
		ColorChat(0, RED, "%s ^1Prowadzacy Mafii ^3%s ^1zginal.", g_GamePrefix, nick);
		
		if(g_GameStatus) ColorChat(0, RED, "%s ^1Potrzebna osoba do dokonczenia zabawy!", g_GamePrefix);
	} else if(is_user_mafia(id)) {
		remove_user_mafia(id);
		ColorChat(0, RED, "%s ^1Zginal ^3%s^1, ktory byl czlonkiem mafii!", g_GamePrefix, nick);
	} else if(id == g_Priest) {
		g_Priest = 0;
		ColorChat(0, RED, "%s ^1Zginal ^3%s^1, ktory byl ksiedzem!", g_GamePrefix, nick);
	} else if(id == g_Agent) {
		g_Agent = 0;
		ColorChat(0, RED, "%s ^1Zginal ^3%s^1, ktory byl agentem!", g_GamePrefix, nick);
	} else if(id == g_Barman) {
		g_Barman = 0;
		ColorChat(0, RED, "%s ^1Zginal ^3%s^1, ktory byl barmanem!", g_GamePrefix, nick);
	} else if(id == g_Hunter) {
		g_Hunter = 0;
		g_HunterSkill = false;
		ColorChat(0, RED, "%s ^1Zginal ^3%s^1, ktory byl lowca!", g_GamePrefix, nick);
	} else if(id == g_PriestVote) {
		g_PriestVote = 0;
		ColorChat(0, RED, "%s ^1Zginal ^3%s^1, ktory byl kandydatem na ksiedza!", g_GamePrefix, nick);
	} else if(id == g_AgentVote) {
		g_AgentVote = 0;
		ColorChat(0, RED, "%s ^1Zginal ^3%s^1, ktory byl kandydatem na agenta!", g_GamePrefix, nick);
	} else if(id == g_BarmanVote) {
		g_BarmanVote = 0;
		ColorChat(0, RED, "%s ^1Zginal ^3%s^1, ktory byl kandydatem na barmana!", g_GamePrefix, nick);
	} else if(id == g_HunterVote) {
		g_HunterVote = 0;
		ColorChat(0, RED, "%s ^1Zginal ^3%s^1, ktory byl kandydatem na lowce!", g_GamePrefix, nick);
	} else {
		if(g_GameStatus) ColorChat(0, RED, "%s ^1Zginal ^3%s^1, ale kogo to obchodzi jak byl nikim.", g_GamePrefix, nick);
	}
	
	if(g_GameStatus) {
		new playersCount = players_count();
		if(ArraySize(g_Mafia) < 1) {
			ColorChat(0, RED, "%s ^1Zginal ostatni czlonek mafii. Miasto wygralo gre w Mafie!!!", g_GamePrefix);
			game_status_manager(false);
		} else if(playersCount <= ArraySize(g_Mafia)) {
			ColorChat(0, RED, "%s ^1Zginal ostatni czlonek miasta. Mafia wygrala gre w Mafie!!!", g_GamePrefix);
			game_status_manager(false);
		}
	}
	
	return PLUGIN_CONTINUE;
}

public new_round() {
	stop_game_tasks();
	for(new i = 0; i < 33; i++) {
		stop_user_tasks(i);
		if(is_user_playing(i)) fast_day(i);
	}
	
	if(!g_MovementStatus) movement_status_manager(true);
	
	start_configuration();
	
	return PLUGIN_CONTINUE;
}

public end_round() {
	stop_game_tasks();
	for(new i = 0; i < 33; i++) {
		stop_user_tasks(i);
		if(is_user_playing(i)) fast_day(i);
	}
	
	if(!g_MovementStatus) movement_status_manager(true);
	
	start_configuration();
	
	return PLUGIN_CONTINUE;
}

public fast_day(id) {
	static msgScreenFade;
	if(!msgScreenFade) msgScreenFade = get_user_msgid("ScreenFade");
	
	message_begin( MSG_ONE, msgScreenFade, {0, 0, 0}, id);
	write_short((1<<12) * 1);
	write_short((1<<12) * 1);
	write_short(0x0004);
	write_byte(255);
	write_byte(255);
	write_byte(255);
	write_byte(0);
	message_end();
}

public game_rules(id) {
	show_motd(id, "mafia_rules.html", "Zasady gry w Mafie");
}

public game_menu(id) {
	if(g_GameLeader) {
		if(g_GameLeader != id) return PLUGIN_HANDLED;
	} else {
		if(!is_user_admin_mafia(id)) return PLUGIN_HANDLED;
	}
	
	new gameMenu = menu_create("[Mafia] Menu Glowne", "game_menu_handler");
	new gameMenuCallback = menu_makecallback("game_menu_callback");
	
	if(g_GameLeader) menu_additem(gameMenu, "\r[ZREZYGNUJ] \wProwadzacy Mafii", .callback = gameMenuCallback);
	else menu_additem(gameMenu, "\y[ZOSTAN] \wProwadzacy Mafii", .callback = gameMenuCallback);
	
	if(g_GameStatus) menu_additem(gameMenu, "\r[WYLACZ] \wGra w Mafie", .callback = gameMenuCallback);
	else menu_additem(gameMenu, "\y[WLACZ] \wGra w Mafie", .callback = gameMenuCallback);
	
	if(g_MovementStatus) menu_additem(gameMenu, "\y[WLACZ] \wBlokada ruchu", .callback = gameMenuCallback);
	else menu_additem(gameMenu, "\r[WYLACZ] \wBlokada ruchu", .callback = gameMenuCallback);
	
	if(g_ExtraPluginsStatus) menu_additem(gameMenu, "\r[WYLACZ] \wPluginy VIP, Ruletka, Sklep", .callback = gameMenuCallback);
	else menu_additem(gameMenu, "\y[WLACZ] \wPluginy VIP, Ruletka, Sklep", .callback = gameMenuCallback);
	
	if(g_TypeOfDay == START && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wGlosowanie miasta", .callback = gameMenuCallback);
	else if(g_TypeOfDay == CITY_VOTE && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wGlosowanie miasta", .callback = gameMenuCallback);
	else if(g_TypeOfDay == CITY_VOTE && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wMiasto idzie spac", .callback = gameMenuCallback);
	else if(g_TypeOfDay == CITY_VOTE_HUNTER && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wGlosowanie lowcy", .callback = gameMenuCallback);
	else if(g_TypeOfDay == HUNTER_VOTE && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wGlosowanie lowcy", .callback = gameMenuCallback);
	else if(g_TypeOfDay == HUNTER_VOTE && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wMiasto idzie spac", .callback = gameMenuCallback);
	else if(g_TypeOfDay == CITY_SLEEP && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wMiasto idzie spac", .callback = gameMenuCallback);
	else if(g_TypeOfDay == CITY_SLEEP && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wMafia budzi sie", .callback = gameMenuCallback);
	else if(g_TypeOfDay == MAFIA_WAKE && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wMafia budzi sie", .callback = gameMenuCallback);
	else if(g_TypeOfDay == MAFIA_WAKE && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wGlosowanie mafii", .callback = gameMenuCallback);
	else if(g_TypeOfDay == MAFIA_VOTE && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wGlosowanie mafii", .callback = gameMenuCallback);
	else if(g_TypeOfDay == MAFIA_VOTE && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wMafia idzie spac", .callback = gameMenuCallback);
	else if(g_TypeOfDay == MAFIA_SLEEP && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wMafia idzie spac", .callback = gameMenuCallback);
	else if(g_TypeOfDay == MAFIA_SLEEP && !g_TypeOfDayStatus) {
		if(g_Priest) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wKsiadz budzi sie", .callback = gameMenuCallback);
		else if(g_Agent) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wAgent budzi sie", .callback = gameMenuCallback);
		else if(g_Barman) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wBarman budzi sie", .callback = gameMenuCallback);
		else menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wMiasto budzi sie", .callback = gameMenuCallback);
	} else if(g_TypeOfDay == PRIEST_WAKE && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wKsiadz budzi sie", .callback = gameMenuCallback);
	else if(g_TypeOfDay == PRIEST_WAKE && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wGlosowanie ksiedza", .callback = gameMenuCallback);
	else if(g_TypeOfDay == PRIEST_VOTE && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wGlosowanie ksiedza", .callback = gameMenuCallback);
	else if(g_TypeOfDay == PRIEST_VOTE && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wKsiadz idzie spac", .callback = gameMenuCallback);
	else if(g_TypeOfDay == PRIEST_SLEEP && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wKsiadz idzie spac", .callback = gameMenuCallback);
	else if(g_TypeOfDay == PRIEST_SLEEP && !g_TypeOfDayStatus) {
		if(g_Agent) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wAgent budzi sie", .callback = gameMenuCallback);
		else if(g_Barman) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wBarman budzi sie", .callback = gameMenuCallback);
		else menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wMiasto budzi sie", .callback = gameMenuCallback);
	} else if(g_TypeOfDay == AGENT_WAKE && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wAgent budzi sie", .callback = gameMenuCallback);
	else if(g_TypeOfDay == AGENT_WAKE && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wGlosowanie agenta", .callback = gameMenuCallback);
	else if(g_TypeOfDay == AGENT_VOTE && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wGlosowanie agenta", .callback = gameMenuCallback);
	else if(g_TypeOfDay == AGENT_VOTE && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wAgent idzie spac", .callback = gameMenuCallback);
	else if(g_TypeOfDay == AGENT_SLEEP && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wAgent idzie spac", .callback = gameMenuCallback);
	else if(g_TypeOfDay == AGENT_SLEEP && !g_TypeOfDayStatus) {
		if(g_Barman) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wBarman budzi sie", .callback = gameMenuCallback);
		else menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wMiasto budzi sie", .callback = gameMenuCallback);
	} else if(g_TypeOfDay == BARMAN_WAKE && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wBarman budzi sie", .callback = gameMenuCallback);
	else if(g_TypeOfDay == BARMAN_WAKE && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wGlosowanie barmana", .callback = gameMenuCallback);
	else if(g_TypeOfDay == BARMAN_VOTE && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wGlosowanie barmana", .callback = gameMenuCallback);
	else if(g_TypeOfDay == BARMAN_VOTE && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wBarman idzie spac", .callback = gameMenuCallback);
	else if(g_TypeOfDay == BARMAN_SLEEP && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wBarman idzie spac", .callback = gameMenuCallback);
	else if(g_TypeOfDay == BARMAN_SLEEP && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wMiasto budzi sie", .callback = gameMenuCallback);
	else if(g_TypeOfDay == CITY_WAKE && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wMiasto budzi sie", .callback = gameMenuCallback);
	else if(g_TypeOfDay == CITY_WAKE && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wRezultat nocnych glosowan", .callback = gameMenuCallback);
	else if(g_TypeOfDay == VOTES_RESULT && g_TypeOfDayStatus) menu_additem(gameMenu, "\r[TRYB TRWA] \wRezultat nocnych glosowan", .callback = gameMenuCallback);
	else if(g_TypeOfDay == VOTES_RESULT && !g_TypeOfDayStatus) menu_additem(gameMenu, "\y[NASTEPNY TRYB] \wGlosowanie miasta", .callback = gameMenuCallback);
	
	menu_additem(gameMenu, "\wObsluga graczy", .callback = gameMenuCallback);
	
	menu_setprop(gameMenu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(gameMenu, MPROP_BACKNAME, "Poprzednia strona");
	menu_setprop(gameMenu, MPROP_NEXTNAME, "Nastepna strona");
	menu_setprop(gameMenu, MPROP_EXITNAME, "Wyjdz");
	menu_display(id, gameMenu);
	
	return PLUGIN_HANDLED;
}

public game_menu_callback(id, menu, item) {
	if(item == 0) {
		if(!g_GameLeader) return ITEM_ENABLED;
		else {
			if(is_user_admin_mafia(id)) return ITEM_ENABLED;
		}
		
		return ITEM_DISABLED;
	} else if(item == 1 || item == 2 || item == 3) {
		if(g_GameLeader) {
			if(g_GameLeader == id) return ITEM_ENABLED;
		}
		
		return ITEM_DISABLED;
	} else if(item == 5) {
		if(g_GameLeader) {
			if(g_GameLeader == id) {
				if(!g_GameStatus) return ITEM_ENABLED;
			}
		}
		
		return ITEM_DISABLED;
	} else {
		if(g_GameLeader) {
			if(g_GameLeader == id) {
				if(g_GameStatus && !g_TypeOfDayStatus) return ITEM_ENABLED;
			}
		}
		
		return ITEM_DISABLED;
	}
	
	return ITEM_DISABLED;
}

public game_menu_handler(id, menu, item) {
	if(item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	if(item == 0) {
		if(g_GameLeader) {
			if(g_GameLeader != id) return PLUGIN_HANDLED;
		} else {
			if(!is_user_admin_mafia(id)) return PLUGIN_HANDLED;
		}
	} else if(item == 1 || item == 2 || item == 3) {
		if(g_GameLeader) {
			if(g_GameLeader != id) return PLUGIN_HANDLED;
		} else return PLUGIN_HANDLED;
	} else if(item == 5){
		if(g_GameLeader) {
			if(g_GameLeader == id) {
				if(g_GameStatus) return PLUGIN_HANDLED;
			} else return PLUGIN_HANDLED;
		} else return PLUGIN_HANDLED;
	} else {
		if(g_GameLeader) {
			if(g_GameLeader == id) {
				if(!g_GameStatus) return PLUGIN_HANDLED;
			} else return PLUGIN_HANDLED;
		} else return PLUGIN_HANDLED;
	}
	
	switch(item) {
		case 0: {
			game_leader_manager(id);
			menu_destroy(menu);
			game_menu(id);
		}
		case 1: {
			game_status_manager(!g_GameStatus);
			menu_destroy(menu);
			game_menu(id);
		}
		case 2: {
			movement_status_manager(!g_MovementStatus);
			menu_destroy(menu);
			game_menu(id);
		}
		case 3: {
			plugins_status_manager(!g_ExtraPluginsStatus);
			menu_destroy(menu);
			game_menu(id);
		}
		case 4: {
			type_of_day_manager();
			menu_destroy(menu);
			game_menu(id);
		}
		case 5: {
			users_manager_menu(id, 0);
			menu_destroy(menu);
		}
	}
	
	return PLUGIN_HANDLED;
}

public game_leader_manager(id) {
	new nick[33]; get_user_name(id, nick, charsmax(nick));
	if(g_GameLeader) {
		g_GameLeader = 0;
		set_user_godmode(id, 0);
		
		ColorChat(0, RED, "%s ^3%s ^1zrezygnowal z Prowadzacego Mafii.", g_GamePrefix, nick);
	} else {
		g_GameLeader = id;
		set_user_godmode(id, 1);
		
		ColorChat(0, RED, "%s ^1Prowadzacym Mafii zostal ^3%s^1! On tu teraz rzadzi!", g_GamePrefix, nick);
	}
}

public game_status_manager(bool:status) {
	if(status) {
		for(new i = 0; i < 33; i++) {
			if(g_VoteTime[i] > 0) {
				ColorChat(g_GameLeader, RED, "%s ^1Nie mozesz teraz wlaczyc zabawy. Jeszcze trwa akceptacja frakcji!", g_GamePrefix);
				return;
			}
		}
	}
	
	g_GameStatus = status;
	
	if(status) {
		ColorChat(0, RED, "%s ^1Rozpoczecie gry w Mafie!", g_GamePrefix);
		set_task(0.2, "game_hud", 5000, .flags = "b");
	} else {
		ColorChat(0, RED, "%s ^1Koniec gry w Mafie!", g_GamePrefix);
		
		if(!g_MovementStatus) movement_status_manager(true);
		
		stop_game_tasks();
		start_configuration();
		for(new i = 0; i < 33; i++) {
			stop_user_tasks(i);
			if(is_user_playing(i)) fast_day(i);
		}
	}
}

public game_hud() {
	new msgTitle[] = "[Zabawa] Mafia";
	
	new szCity[30] = "", szMafia[30] = "", szPriest[30] = "", szAgent[30] = "", szBarman[30] = "", szHunter[30] = "";
	new playersCount = players_count(), mafiaCount = ArraySize(g_Mafia), cityCount = playersCount - mafiaCount;
	if(mafiaCount > 0) formatex(szMafia, charsmax(szMafia), "[%d] Czlonkowie Mafii^n^n", mafiaCount);
	if(cityCount > 0) formatex(szCity, charsmax(szCity), "[%d] Mieszkancy (bez Mafii)^n", cityCount);
	if(g_Priest) formatex(szPriest, charsmax(szPriest), "[1] Ksiadz^n");
	if(g_Agent) formatex(szAgent, charsmax(szAgent), "[1] Agent^n");
	if(g_Barman) formatex(szBarman, charsmax(szBarman), "[1] Barman^n");
	if(g_Hunter) formatex(szHunter, charsmax(szHunter), "[1] Lowca^n");
	
	new szFractions[180];
	formatex(szFractions, charsmax(szFractions), "%s%s%s%s%s%s", szMafia, szCity, szPriest, szAgent, szBarman, szHunter);
	
	new msg[200];
	formatex(msg, charsmax(msg), "%s^n%s", msgTitle, szFractions);
	
	set_hudmessage(0, 255, 42, 0.8, 0.3, 0, 6.0, 1.0);
	show_hudmessage(0, msg);
}

public movement_status_manager(bool:status) {
	g_MovementStatus = status;
	
	if(status) ColorChat(0, RED, "%s ^1Blokada ruchu wylaczona!", g_GamePrefix);
	else ColorChat(0, RED, "%s ^1Blokada ruchu wlaczona!", g_GamePrefix);
	
	new players[32], playersNumber; get_players(players, playersNumber);
	for(new i = 0; i < playersNumber; i++) {
		new idPlayer = players[i];
		
		if(!is_user_playing(idPlayer)) continue;
		
		if(status) set_pev( idPlayer, pev_flags, pev( idPlayer, pev_flags ) & ~FL_FROZEN );
		else set_pev( idPlayer, pev_flags, pev( idPlayer, pev_flags ) | FL_FROZEN );
	}
}

public plugins_status_manager(bool:status) {
	g_ExtraPluginsStatus = status;
	
	if(status) {
		ColorChat(0, RED, "%s ^1Pluginy VIP, Ruletka i Sklep zostaly ponownie wlaczone!", g_GamePrefix);
		unpause("ac", "jbe_vip.amxx");
		unpause("ac", "jbe_shop.amxx");
		unpause("ac", "jbe_roulette.amxx");
	} else {
		ColorChat(0, RED, "%s ^1Pluginy VIP, Ruletka i Sklep zostaly zatrzymane", g_GamePrefix);
		pause("ac", "jbe_vip.amxx");
		pause("ac", "jbe_shop.amxx");
		pause("ac", "jbe_roulette.amxx");
	}
}

public type_of_day_manager() {
	switch(g_TypeOfDay) {
		case START: city_vote();
		case CITY_VOTE: city_sleep();
		case CITY_VOTE_HUNTER: hunter_vote();
		case HUNTER_VOTE: city_sleep();
		case CITY_SLEEP: mafia_wake();
		case MAFIA_WAKE: mafia_vote();
		case MAFIA_VOTE: mafia_sleep();
		case MAFIA_SLEEP: {
			if(g_Priest) single_wake(PRIEST_WAKE);
			else if(g_Agent) single_wake(AGENT_WAKE);
			else if(g_Barman) single_wake(BARMAN_WAKE);
			else city_wake();
		}
		case PRIEST_WAKE: priest_vote();
		case PRIEST_VOTE: single_sleep(PRIEST_SLEEP);
		case PRIEST_SLEEP: {
			if(g_Agent) single_wake(AGENT_WAKE);
			else if(g_Barman) single_wake(BARMAN_WAKE);
			else city_wake();
		}
		case AGENT_WAKE: agent_vote();
		case AGENT_VOTE: single_sleep(AGENT_SLEEP);
		case AGENT_SLEEP: {
			if(g_Barman) single_wake(BARMAN_WAKE);
			else city_wake();
		}
		case BARMAN_WAKE: barman_vote();
		case BARMAN_VOTE: single_sleep(BARMAN_SLEEP);
		case BARMAN_SLEEP: city_wake();
		case CITY_WAKE: votes_result();
		case VOTES_RESULT: city_vote();
	}
}


////////////////////CITY VOTE
public city_vote() {
	g_TypeOfDayStatus = true;
	g_TypeOfDay = CITY_VOTE;
	
	ColorChat(0, RED, "%s ^1Czas na glosowanie miasta!", g_CityVotePrefix);
	ColorChat(0, RED, "%s ^1Za^3 5s ^1rozpocznie sie vote w celu wybrania osoby do zabicia!", g_CityVotePrefix);
	set_task(5.0, "city_vote_delay", 1000, .flags = "a", .repeat = 1);
}

public city_vote_delay() {
	new players[32], playersNumber; get_players(players, playersNumber);
	for(new i = 0; i < playersNumber; i++) {
		new idPlayer = players[i];
		
		if(!is_user_playing(idPlayer)) continue;
		
		new szIdPlayer[3]; num_to_str(idPlayer, szIdPlayer, charsmax(szIdPlayer));

		g_VoteTime[idPlayer] = g_TimeForVote;
		set_task(1.0, "players_menu", idPlayer + 3000, szIdPlayer, charsmax(szIdPlayer), "b");
	}
	
	set_task(1.0, "is_city_vote_during", 2000, .flags = "b");
}

public city_vote_handler(id, menu, item) {
	if(item < 0) return 0;
	
	remove_task(id + 3000);
	show_menu(id, 0, "^n", 1);
	g_VoteTime[id] = 0;
	
	new szIdPlayer[3], nick[33], access, callback;
	menu_item_getinfo(menu, item, access, szIdPlayer, charsmax(szIdPlayer), nick, charsmax(nick), callback);
	new idPlayer = str_to_num(szIdPlayer);
	
	ColorChat(id, RED, "%s ^1Wybrales ^3%s ^1do zabicia!", g_CityVotePrefix, nick);
	g_VoteCount[idPlayer]++;
	
	return PLUGIN_HANDLED;
}

public is_city_vote_during() {
	for(new i = 0; i < 33; i++) {
		if(g_VoteTime[i] > 0) return;
	}
	
	remove_task(2000);
	city_vote_result();
}

public city_vote_result() {
	new biggestCount = g_VoteCount[0], id = 0;
	for(new i = 1; i < 33; i++) {
		if(g_VoteCount[i] > biggestCount) {
			biggestCount = g_VoteCount[i];
			id = i;
		}
		
		g_VoteCount[i] = 0;
	}
	
	if(id == 0) {
		ColorChat(0, RED, "%s ^1Miasto nikogo nie wybralo, wiec tym razem nikt nie zginie.", g_CityVotePrefix);
		type_of_day_status_manager();
	} else {
		new nick[33]; get_user_name(id, nick, charsmax(nick));
		ColorChat(0, RED, "%s ^1Miasto wybralo ^3%s ^4(%d glosow) ^1do zabicia!", g_CityVotePrefix, nick, biggestCount);
		
		if(id == g_Hunter && g_HunterSkill) {
			ColorChat(0, RED, "%s ^3%s ^1jest ^3lowca^1! To jego ostatnia szansa na odwrocenie losu!", g_CityVotePrefix, nick);
			g_TypeOfDay = CITY_VOTE_HUNTER;
			type_of_day_status_manager();
		} else {
			new szId[3]; num_to_str(id, szId, charsmax(szId));
			set_task(1.0, "user_kill_delay", 1001, szId, charsmax(szId), "a", 1);
		}
	}
	
	return PLUGIN_HANDLED;
}
/////////////////////////////

////////////////////HUNTER VOTE
public hunter_vote() {
	g_TypeOfDayStatus = true;
	g_TypeOfDay = HUNTER_VOTE;
	
	g_HunterSkill = false;
	
	ColorChat(0, RED, "%s ^1Czas na glosowanie lowcy!", g_HunterVotePrefix);
	ColorChat(g_Hunter, RED, "%s ^1Za^3 3s ^1rozpocznie sie vote w celu wybrania osoby do zabicia!", g_HunterVotePrefix);
	set_task(3.0, "single_vote_delay", 1002, .flags = "a", .repeat = 1);
}

public hunter_vote_result() {
	if(g_HunterChoice) {
		new nick[33]; get_user_name(g_HunterChoice, nick, charsmax(nick));
		ColorChat(0, RED, "%s ^3Lowca ^1wybral ^3%s ^1do zabicia!", g_HunterVotePrefix, nick);
		
		new szId[3]; num_to_str(g_HunterChoice, szId, charsmax(szId));
		set_task(1.0, "user_kill_delay", 1003, szId, charsmax(szId), "a", 1);
		g_HunterChoice = 0;
	} else {
		ColorChat(0, RED, "%s ^3Lowca ^1nikogo nie wybral i zmarnowal swoja szanse!", g_HunterVotePrefix);
		type_of_day_status_manager();
	}
}
/////////////////////////////

////////////////////CITY SLEEP
public city_sleep() {
	g_TypeOfDayStatus = true;
	g_TypeOfDay = CITY_SLEEP;
	
	set_hudmessage(255, 255, 255, -1.0, 0.35, 0, 2.0, 4.0, 0.1, 0.3, 2);
	new players[32], playersNumber; get_players(players, playersNumber);
	for(new i = 0; i < playersNumber; i++) {
		new idPlayer = players[i];
		
		if(!is_user_playing(idPlayer)) continue;
		
		new parameters[5];
		new szIdPlayer[3]; num_to_str(idPlayer, szIdPlayer, charsmax(szIdPlayer));
		formatex(parameters, charsmax(parameters), "%s 1", szIdPlayer);
		set_task(0.2, "night", idPlayer + 500, parameters, charsmax(parameters), "a", 1);
		show_hudmessage(idPlayer, "Miasto zasypia!");
		
		formatex(parameters, charsmax(parameters), "%s 4", szIdPlayer);
		set_task(1.8, "night", idPlayer + 500, parameters, charsmax(parameters), "a", 1);
	}
	
	set_task(3.0, "type_of_day_delay", 1000, .flags = "a", .repeat = 1);
}

public night(data[]) {
	new szId[3], szTypeOfFade[2];
	split(data, szId, charsmax(szId), szTypeOfFade, charsmax(szTypeOfFade), " ");
	new id = str_to_num(szId), short:typeOfFade = short:str_to_num(szTypeOfFade);
	
	static msgScreenFade;
	if(!msgScreenFade) msgScreenFade = get_user_msgid("ScreenFade");
	
	message_begin( MSG_ONE, msgScreenFade, {0, 0, 0}, id);
	write_short((1<<12) * 1);
	write_short((1<<12) * 2);
	write_short(typeOfFade);
	write_byte(0);
	write_byte(0);
	write_byte(0);
	write_byte(255);
	message_end();
}
/////////////////////////////

////////////////////MAFIA WAKE
public mafia_wake() {
	g_TypeOfDayStatus = true;
	g_TypeOfDay = MAFIA_WAKE;
	
	set_hudmessage(255, 255, 255, -1.0, 0.35, 0, 2.0, 4.0, 0.1, 0.3, 2);
	new players[32], playersNumber; get_players(players, playersNumber);
	for(new i = 0; i < playersNumber; i++) {
		new idPlayer = players[i];
		
		if(!is_user_playing(idPlayer)) continue;
		
		show_hudmessage(idPlayer, "Mafia budzi sie!");		
	}
	
	for(new i = 0; i < ArraySize(g_Mafia); i++) {
		new idPlayer = ArrayGetCell(g_Mafia, i);
		
		new parameters[5];
		new szIdPlayer[3]; num_to_str(idPlayer, szIdPlayer, charsmax(szIdPlayer));
		formatex(parameters, charsmax(parameters), "%s 0", szIdPlayer);
		set_task(0.2, "night", idPlayer + 500, parameters, charsmax(parameters), "a", 1);
		
		ColorChat(idPlayer, RED, "%s ^1Komenda^3 /chat tekst ^1sluzy do porozumienia sie z innymi czlonkami mafii!", g_GamePrefix);
	}
	
	set_task(2.0, "type_of_day_delay", 1000, .flags = "a", .repeat = 1);
}
/////////////////////////////


////////////////////MAFIA VOTE
public mafia_vote() {
	g_TypeOfDayStatus = true;
	g_TypeOfDay = MAFIA_VOTE;
	
	ColorChat(0, RED, "%s ^1Czas na glosowanie mafii!", g_MafiaVotePrefix);
	for(new i = 0; i < ArraySize(g_Mafia); i++) {
		new idPlayer = ArrayGetCell(g_Mafia, i);
		ColorChat(idPlayer, RED, "%s ^1Za^3 5s ^1rozpocznie sie vote w celu wybrania osoby do zabicia!", g_MafiaVotePrefix);
	}
	
	set_task(5.0, "mafia_vote_delay", 1000, .flags = "a", .repeat = 1);
}

public mafia_vote_delay() {
	for(new i = 0; i < ArraySize(g_Mafia); i++) {
		new idPlayer = ArrayGetCell(g_Mafia, i);
		
		new szIdPlayer[3]; num_to_str(idPlayer, szIdPlayer, charsmax(szIdPlayer));
		
		g_VoteTime[idPlayer] = g_TimeForVote;
		set_task(1.0, "players_menu", idPlayer + 3000, szIdPlayer, charsmax(szIdPlayer), "b");
	}
	
	set_task(1.0, "is_mafia_vote_during", 2000, .flags = "b");
}

public mafia_vote_handler(id, menu, item) {
	if(item < 0) return 0;
	
	remove_task(id + 3000);
	show_menu(id, 0, "^n", 1);
	g_VoteTime[id] = 0;
	
	new szIdPlayer[3], nick[33], access, callback;
	menu_item_getinfo(menu, item, access, szIdPlayer, charsmax(szIdPlayer), nick, charsmax(nick), callback);
	new idPlayer = str_to_num(szIdPlayer);
	
	ColorChat(id, RED, "%s ^1Wybrales ^3%s ^1do zabicia!", g_MafiaVotePrefix, nick);
	g_VoteCount[idPlayer]++;
	
	return PLUGIN_HANDLED;
}

public is_mafia_vote_during() {
	for(new i = 0; i < 33; i++) {
		if(g_VoteTime[i] > 0) return;
	}
	
	remove_task(2000);
	mafia_vote_result();
}

public mafia_vote_result() {
	new biggestCount = g_VoteCount[0], id = 0;
	for(new i = 1; i < 33; i++) {
		if(g_VoteCount[i] > biggestCount) {
			biggestCount = g_VoteCount[i];
			id = i;
		}
		
		g_VoteCount[i] = 0;
	}
	
	g_MafiaChoice = id;
	for(new i = 0; i < ArraySize(g_Mafia); i++) {
		new idPlayer = ArrayGetCell(g_Mafia, i);
		
		new nick[33]; get_user_name(g_MafiaChoice, nick, charsmax(nick));
		
		if(g_MafiaChoice) ColorChat(idPlayer, RED, "%s ^1Ostatecznie wybraliscie ^3%s ^1do zabicia!", g_MafiaVotePrefix, nick);
		else ColorChat(idPlayer, RED, "%s ^1Ostatecznie nikogo nie wybraliscie do zabicia!", g_MafiaVotePrefix);
	}
	
	type_of_day_status_manager();
}
/////////////////////////////

////////////////////MAFIA SLEEP
public mafia_sleep() {
	g_TypeOfDayStatus = true;
	g_TypeOfDay = MAFIA_SLEEP;
	
	set_hudmessage(255, 255, 255, -1.0, 0.35, 0, 2.0, 4.0, 0.1, 0.3, 2);
	new players[32], playersNumber; get_players(players, playersNumber);
	for(new i = 0; i < playersNumber; i++) {
		new idPlayer = players[i];
		
		if(!is_user_playing(idPlayer)) continue;
		
		show_hudmessage(idPlayer, "Mafia zasypia!");	
	}
	
	for(new i = 0; i < ArraySize(g_Mafia); i++) {
		new idPlayer = ArrayGetCell(g_Mafia, i);
		
		new parameters[5];
		new szIdPlayer[3]; num_to_str(idPlayer, szIdPlayer, charsmax(szIdPlayer));
		formatex(parameters, charsmax(parameters), "%s 1", szIdPlayer);
		set_task(0.2, "night", idPlayer + 500, parameters, charsmax(parameters), "a", 1);
		
		formatex(parameters, charsmax(parameters), "%s 4", szIdPlayer);
		set_task(1.8, "night", idPlayer + 500, parameters, charsmax(parameters), "a", 1);
	}
	
	set_task(2.0, "type_of_day_delay", 1000, .flags = "a", .repeat = 1);
}
/////////////////////////////

////////////////////SINGLE WAKE
public single_wake(typeOfDay) {
	g_TypeOfDayStatus = true;
	
	new hudMsg[100], id;
	switch(typeOfDay) {
		case PRIEST_WAKE: {
			g_TypeOfDay = PRIEST_WAKE;
			id = g_Priest;
			hudMsg = "Ksiadz budzi sie!";
		}
		case AGENT_WAKE: {
			g_TypeOfDay = AGENT_WAKE;
			id = g_Agent;
			hudMsg = "Agent budzi sie!";
		}
		case BARMAN_WAKE: {
			g_TypeOfDay = BARMAN_WAKE;
			id = g_Barman;
			hudMsg = "Barman budzi sie!";
		}
	}
	
	set_hudmessage(255, 255, 255, -1.0, 0.35, 0, 2.0, 4.0, 0.1, 0.3, 2);
	
	new players[32], playersNumber; get_players(players, playersNumber);
	for(new i = 0; i < playersNumber; i++) {
		new idPlayer = players[i];
		
		if(!is_user_playing(idPlayer)) continue;
		
		show_hudmessage(idPlayer, hudMsg);		
	}
	
	new parameters[5];
	if(id) {
		new szId[3]; num_to_str(id, szId, charsmax(szId));
		formatex(parameters, charsmax(parameters), "%s 0", szId);
		set_task(0.2, "night", id + 500, parameters, charsmax(parameters), "a", 1);
	}
	
	set_task(2.0, "type_of_day_delay", 1000, .flags = "a", .repeat = 1);
}
/////////////////////////////

////////////////////SINGLE VOTE
public priest_vote() {
	g_TypeOfDayStatus = true;
	g_TypeOfDay = PRIEST_VOTE;
	
	ColorChat(0, RED, "%s ^1Czas na glosowanie ksiedza!", g_PriestVotePrefix);
	ColorChat(g_Priest, RED, "%s ^1Za^3 3s ^1rozpocznie sie vote w celu wybrania osoby do modlitwy!", g_PriestVotePrefix);
	set_task(3.0, "single_vote_delay", 1002, .flags = "a", .repeat = 1);
}

public agent_vote() {
	g_TypeOfDayStatus = true;
	g_TypeOfDay = AGENT_VOTE;
	
	ColorChat(0, RED, "%s ^1Czas na glosowanie agenta!", g_AgentVotePrefix);
	ColorChat(g_Agent, RED, "%s ^1Za^3 3s ^1rozpocznie sie vote w celu wybrania osoby do sprawdzenia!", g_AgentVotePrefix);
	set_task(3.0, "single_vote_delay", 1002, .flags = "a", .repeat = 1);
}

public barman_vote() {
	g_TypeOfDayStatus = true;
	g_TypeOfDay = BARMAN_VOTE;
	
	ColorChat(0, RED, "%s ^1Czas na glosowanie barmana!", g_BarmanVotePrefix);
	ColorChat(g_Barman, RED, "%s ^1Za^3 3s ^1rozpocznie sie vote w celu wybrania osoby do zabicia!", g_BarmanVotePrefix);
	set_task(3.0, "single_vote_delay", 1002, .flags = "a", .repeat = 1);
}

public single_vote_delay() {
	new id;
	switch(g_TypeOfDay) {
		case HUNTER_VOTE: id = g_Hunter;
		case PRIEST_VOTE: id = g_Priest;
		case AGENT_VOTE: id = g_Agent;
		case BARMAN_VOTE: id = g_Barman;
	}
	
	g_VoteTime[id] = g_TimeForVote;
	
	new szId[3];  num_to_str(id, szId, charsmax(szId));
	set_task(1.0, "players_menu", id + 3000, szId, charsmax(szId), "b");
	
	set_task(1.5, "is_single_vote_during", 2000, szId, charsmax(szId), "b");
}

public single_vote_handler(id, menu, item) {
	if(item < 0) return 0;
	
	remove_task(id + 3000);
	show_menu(id, 0, "^n", 1);
	g_VoteTime[id] = 0;
	
	new szIdPlayer[3], nick[33], access, callback;
	menu_item_getinfo(menu, item, access, szIdPlayer, charsmax(szIdPlayer), nick, charsmax(nick), callback);
	new idPlayer = str_to_num(szIdPlayer);
	
	switch(g_TypeOfDay) {
		case HUNTER_VOTE: {
			ColorChat(id, RED, "%s ^1Wybrales ^3%s ^1do zabicia!", g_HunterVotePrefix, nick);
			g_HunterChoice = idPlayer;
		}
		case PRIEST_VOTE: {
			ColorChat(id, RED, "%s ^1Wybrales ^3%s ^1do modlitwy!", g_PriestVotePrefix, nick);
			g_PriestChoice = idPlayer;
		}
		case AGENT_VOTE: {
			ColorChat(id, RED, "%s ^1Wybrales ^3%s ^1do sprawdzenia!", g_AgentVotePrefix, nick);
			g_AgentChoice = idPlayer;
		}
		case BARMAN_VOTE: {
			ColorChat(id, RED, "%s ^1Wybrales ^3%s ^1do upicia!", g_BarmanVotePrefix, nick);
			g_BarmanChoice = idPlayer;
		}
	}
	
	return PLUGIN_HANDLED;
}

public is_single_vote_during(data[]) {
	new id = str_to_num(data);
	if(g_VoteTime[id] > 0) return;
	
	remove_task(2000);
	
	if(g_TypeOfDay == HUNTER_VOTE) hunter_vote_result();
	else type_of_day_status_manager();
}

public user_kill_delay(data[]) {
	new id = str_to_num(data);
	user_kill(id);
	type_of_day_status_manager();
}
/////////////////////////////

////////////////////SINGLE SLEEP
public single_sleep(typeOfDay) {
	g_TypeOfDayStatus = true;
	
	new hudMsg[100], id;
	switch(typeOfDay) {
		case PRIEST_SLEEP: {
			g_TypeOfDay = PRIEST_SLEEP;
			id = g_Priest;
			hudMsg = "Ksiadz idzie spac!";
		}
		case AGENT_SLEEP: {
			g_TypeOfDay = AGENT_SLEEP;
			id = g_Agent;
			hudMsg = "Agent idzie spac!";
		}
		case BARMAN_SLEEP: {
			g_TypeOfDay = BARMAN_SLEEP;
			id = g_Barman;
			hudMsg = "Barman idzie spac!";
		}
	}
	
	set_hudmessage(255, 255, 255, -1.0, 0.35, 0, 2.0, 4.0, 0.1, 0.3, 2);
	
	new players[32], playersNumber; get_players(players, playersNumber);
	for(new i = 0; i < playersNumber; i++) {
		new idPlayer = players[i];
		
		if(!is_user_playing(idPlayer)) continue;
		
		show_hudmessage(idPlayer, hudMsg);		
	}
	
	new parameters[5];
	if(id) {
		new szId[3]; num_to_str(id, szId, charsmax(szId));
		formatex(parameters, charsmax(parameters), "%s 1", szId);
		set_task(0.2, "night", id + 500, parameters, charsmax(parameters), "a", 1);
		formatex(parameters, charsmax(parameters), "%s 4", szId);
		set_task(1.8, "night", id + 500, parameters, charsmax(parameters), "a", 1);
	}
	
	set_task(2.0, "type_of_day_delay", 1000, .flags = "a", .repeat = 1);
}
/////////////////////////////

////////////////////CITY WAKE
public city_wake() {
	g_TypeOfDayStatus = true;
	g_TypeOfDay = CITY_WAKE;
	
	set_hudmessage(255, 255, 255, -1.0, 0.35, 0, 2.0, 4.0, 0.1, 0.3, 2);
	new players[32], playersNumber; get_players(players, playersNumber);
	for(new i = 0; i < playersNumber; i++) {
		new idPlayer = players[i];
		
		if(!is_user_playing(idPlayer)) continue;
		
		new parameters[5];
		new szIdPlayer[3]; num_to_str(idPlayer, szIdPlayer, charsmax(szIdPlayer));
		formatex(parameters, charsmax(parameters), "%s 0", szIdPlayer);
		set_task(0.2, "night", idPlayer + 500, parameters, charsmax(parameters), "a", 1);
	}
	
	set_task(2.0, "type_of_day_delay", 1000, .flags = "a", .repeat = 1);
}
/////////////////////////////

////////////////////VOTES RESULT
public votes_result() {
	g_TypeOfDayStatus = true;
	g_TypeOfDay = VOTES_RESULT;
	
	ColorChat(0, RED, "%s ^1Czas na rozstrzygniecie nocnych glosowan!", g_VotesResultPrefix);
	set_task(1.0, "votes_result_delay", 1000, .flags = "a", .repeat = 1);
}

public votes_result_delay() {
	if(g_MafiaChoice) {
		new victim = g_MafiaChoice;
		
		if(g_BarmanChoice) {
			ColorChat(0, RED, "%s ^1Barman upija, ale czy upil dobra osobe? Kto to moze wiedziec?", g_VotesResultPrefix);
			
			if(is_user_mafia(g_BarmanChoice)) victim = random_user();
		}
		
		new nick[33]; get_user_name(victim, nick, charsmax(nick));
		ColorChat(0, RED, "%s ^1Mafia wybrala ^3%s ^1do zabicia!", g_VotesResultPrefix, nick);
		
		new szId[3]; num_to_str(victim, szId, charsmax(szId));
		if(g_Priest) {
			set_task(1.5, "priest_result", 1001, szId, charsmax(szId), "a", 1);
		} else {
			if(g_Agent) {
				if(victim == g_Agent) {
					set_task(1.0, "user_kill_delay", 1001, szId, charsmax(szId), "a", 1);
				} else {
					set_task(1.0, "agent_result", 1001, .flags = "a", .repeat = 1);
					set_task(2.0, "user_kill_delay", 1002, szId, charsmax(szId), "a", 1);
				}
			} else {
				set_task(1.0, "user_kill_delay", 1001, szId, charsmax(szId), "a", 1);
			}
		}
	} else {
		ColorChat(0, RED, "%s ^1Mafia nikogo nie wybrala do zabicia.", g_VotesResultPrefix);
		
		if(g_Agent) {
			set_task(1.0, "agent_result", 1001, .flags = "a", .repeat = 1);
			set_task(2.5, "type_of_day_delay", 1002, .flags = "a", .repeat = 1);
		} else {
			set_task(1.5, "type_of_day_delay", 1001, .flags = "a", .repeat = 1);
		}
		
	}
	
	set_task(4.0, "zeruj", 1008, .flags = "a", .repeat = 1);
}

public zeruj() {
	g_MafiaChoice = 0;
	g_PriestChoice = 0;
	g_AgentChoice = 0;
	g_BarmanChoice = 0;
}

public priest_result(data[]) {
	new id = str_to_num(data);
	
	if(id == g_PriestChoice) {
		ColorChat(0, RED, "%s ^1Ksiadz dobrze sie pomodlil! Nikt nie zginal.", g_VotesResultPrefix);
		
		if(g_Agent) {
			set_task(1.0, "agent_result", 1003, .flags = "a", .repeat = 1);
			set_task(2.5, "type_of_day_delay", 1004, .flags = "a", .repeat = 1);
		} else {
			set_task(1.5, "type_of_day_delay", 1003, .flags = "a", .repeat = 1);
		}
	} else {
		ColorChat(0, RED, "%s ^1Tym razem ksiadz sie pomylil!", g_VotesResultPrefix);
		
		new szId[3]; num_to_str(id, szId, charsmax(szId));
		if(id == g_Agent) {
			set_task(1.5, "user_kill_delay", 1003, szId, charsmax(szId), "a", 1);
		} else {
			if(g_Agent) {
				set_task(1.0, "agent_result", 1003, .flags = "a", .repeat = 1);
				set_task(2.5, "user_kill_delay", 1004, szId, charsmax(szId), "a", 1);
			} else {
				set_task(1.5, "user_kill_delay", 1003, szId, charsmax(szId), "a", 1);
			}
		}
	}
}

public agent_result() {
	new nick[33]; get_user_name(g_AgentChoice, nick, charsmax(nick));
	if(is_user_mafia(g_AgentChoice)) {
		ColorChat(0, RED, "%s ^1Agent trafil w mafie!", g_VotesResultPrefix);
		ColorChat(g_Agent, RED, "%s ^1Trafiles w mafioze! Czlonkiem mafii jest ^3%s^1!", g_VotesResultPrefix, nick);
	} else {
		ColorChat(0, RED, "%s ^1Agent sie pomylil i nie trafil w mafie.", g_VotesResultPrefix);
		ColorChat(g_Agent, RED, "%s ^1Tym razem nie trafiles w mafioze. ^3%s nie jest czlonkiem mafii.", g_VotesResultPrefix, nick);
	}
}

public random_user() {
	new players[32], playersNumber; get_players(players, playersNumber);
	new id;
	do {
		id = random(playersNumber - 1) + 1;
	} while(!is_user_playing(id));
	
	return id;
}
/////////////////////////////

public type_of_day_delay() {
	type_of_day_status_manager();
}

public type_of_day_status_manager() {
	g_TypeOfDayStatus = false;
	if(g_GameLeader) game_menu(g_GameLeader);
	
	new msg[100];
	switch(g_TypeOfDay) {
		case CITY_VOTE: formatex(msg, charsmax(msg), "%s ^1Glosowanie miasta zostalo zakonczone." ,g_GamePrefix);
		case CITY_SLEEP: formatex(msg, charsmax(msg), "%s ^1Miasto zasnelo." ,g_GamePrefix);
		case MAFIA_WAKE: formatex(msg, charsmax(msg), "%s ^1Mafia obudzila sie." ,g_GamePrefix);
		case MAFIA_VOTE: formatex(msg, charsmax(msg), "%s ^1Glosowanie mafii zostalo zakonczone." ,g_GamePrefix);
		case MAFIA_SLEEP: formatex(msg, charsmax(msg), "%s ^1Mafia zasnela." ,g_GamePrefix);
		case PRIEST_WAKE: formatex(msg, charsmax(msg), "%s ^1Ksiadz obudzil sie." ,g_GamePrefix);
		case PRIEST_VOTE: formatex(msg, charsmax(msg), "%s ^1Glosowanie ksiedza zostalo zakonczone." ,g_GamePrefix);
		case PRIEST_SLEEP: formatex(msg, charsmax(msg), "%s ^1Ksiadz zasnal." ,g_GamePrefix);
		case AGENT_WAKE: formatex(msg, charsmax(msg), "%s ^1Agent obudzil sie." ,g_GamePrefix);
		case AGENT_VOTE: formatex(msg, charsmax(msg), "%s ^1Glosowanie agenta zostalo zakonczone." ,g_GamePrefix);
		case AGENT_SLEEP: formatex(msg, charsmax(msg), "%s ^1Agent zasnal." ,g_GamePrefix);
		case BARMAN_WAKE: formatex(msg, charsmax(msg), "%s ^1Barman obudzil sie." ,g_GamePrefix);
		case BARMAN_VOTE: formatex(msg, charsmax(msg), "%s ^1Glosowanie barmana zostalo zakonczone." ,g_GamePrefix);
		case BARMAN_SLEEP: formatex(msg, charsmax(msg), "%s ^1Barman zasnal." ,g_GamePrefix);
		case CITY_WAKE: formatex(msg, charsmax(msg), "%s ^1Miasto obudzilo sie" ,g_GamePrefix);
		case VOTES_RESULT: formatex(msg, charsmax(msg), "%s ^1Nocne glosowania zostaly rozstrzygniete" ,g_GamePrefix);
	}
	
	ColorChat(0, RED, msg);
}

public users_manager_menu(id, page) {
	new usersManagerMenu = menu_create("[Mafia] Menu Zarzadzania Graczami", "users_manager_menu_handler");
	new usersManagerMenuCallback = menu_makecallback("users_manager_menu_callback");
	
	new players[32], playersNumber; get_players(players, playersNumber);
	for(new i = 0, j = 0; i < playersNumber; i++) {
		new idPlayer = players[i];
		
		if(!is_user_playing(idPlayer)) continue;
		
		if(j % 6 == 0) {
			new menuItemTitle[60];
			switch(g_NameOfFraction) {
				case MAFIA: formatex(menuItemTitle, charsmax(menuItemTitle), "%s \wDodaj mafioze", g_NameOfFractionMenuPrefix);
				case PRIEST: formatex(menuItemTitle, charsmax(menuItemTitle), "%s \wDodaj ksiedza", g_NameOfFractionMenuPrefix);
				case AGENT: formatex(menuItemTitle, charsmax(menuItemTitle), "%s \wDodaj agenta", g_NameOfFractionMenuPrefix);
				case BARMAN: formatex(menuItemTitle, charsmax(menuItemTitle), "%s \wDodaj barmana", g_NameOfFractionMenuPrefix);
				case HUNTER: formatex(menuItemTitle, charsmax(menuItemTitle), "%s \wDodaj lowce", g_NameOfFractionMenuPrefix);
				case NONE: formatex(menuItemTitle, charsmax(menuItemTitle), "%s \wUsun funkcje", g_NameOfFractionMenuPrefix);
			}
			menu_additem(usersManagerMenu, menuItemTitle);
		}
		j++;
		
		new szIdPlayer[3]; num_to_str(idPlayer, szIdPlayer, charsmax(szIdPlayer));
		
		new parameters[30];
		new nick[33]; get_user_name(idPlayer, nick, charsmax(nick));
		new szFraction[15] = "";
		if(is_user_mafia(idPlayer)) szFraction = "\y[MAFIA]";
		else if(idPlayer == g_Priest) szFraction = "\y[PRIEST]";
		else if(idPlayer == g_Agent) szFraction = "\y[AGENT]";
		else if(idPlayer == g_Barman) szFraction = "\y[BARMAN]";
		else if(idPlayer == g_Hunter) szFraction = "\y[LOWCA]";
		formatex(parameters, charsmax(parameters), "%s ^t^t^t%s", nick, szFraction);
		
		menu_additem(usersManagerMenu, parameters, szIdPlayer, .callback = usersManagerMenuCallback);
	}
	
	menu_setprop(usersManagerMenu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(usersManagerMenu, MPROP_BACKNAME, "Poprzednia strona");
	menu_setprop(usersManagerMenu, MPROP_NEXTNAME, "Nastepna strona");
	menu_setprop(usersManagerMenu, MPROP_EXITNAME, "Wroc do Menu Glownego");
	menu_display(id, usersManagerMenu, page);
}

public users_manager_menu_callback(id, menu, item) {
	new szIdPlayer[3], nick[33], access, callback;
	menu_item_getinfo(menu, item, access, szIdPlayer, charsmax(szIdPlayer), nick, charsmax(nick), callback);
	
	new idPlayer = str_to_num(szIdPlayer);
	if(g_NameOfFraction == NONE) {
		if(is_user_mafia(idPlayer) || idPlayer == g_Priest || idPlayer == g_Agent ||
			idPlayer == g_Barman || idPlayer == g_Hunter) return ITEM_ENABLED;
		return ITEM_DISABLED;
	} else {
		if(!is_user_mafia(idPlayer) && idPlayer != g_Priest && idPlayer != g_Agent &&
			idPlayer != g_Barman && idPlayer != g_Hunter && g_VoteTime[idPlayer] == 0) {
			if(g_NameOfFraction == PRIEST) {
				if(!g_PriestVote && !g_Priest) return ITEM_ENABLED;
				return ITEM_DISABLED;
			} else if(g_NameOfFraction == AGENT) {
				if(!g_AgentVote && !g_Agent) return ITEM_ENABLED;
				return ITEM_DISABLED;
			} else if(g_NameOfFraction == BARMAN) {
				if(!g_BarmanVote && !g_Barman) return ITEM_ENABLED;
				return ITEM_DISABLED;
			} else if(g_NameOfFraction == HUNTER) {
				if(!g_HunterVote && !g_Hunter) return ITEM_ENABLED;
				return ITEM_DISABLED;
			} else {
				return ITEM_ENABLED;
			}
		}
		return ITEM_DISABLED;
	}
	
	return ITEM_DISABLED;
}

public users_manager_menu_handler(id, menu, item) {
	if(item == MENU_EXIT) {
		menu_destroy(menu);
		game_menu(id);
		return PLUGIN_HANDLED;
	}
	
	if(g_GameStatus) {
		return PLUGIN_HANDLED;
	} else {
		if(id != g_GameLeader) return PLUGIN_HANDLED;
	}
	
	
	if(item % 7 == 0) {
		switch(g_NameOfFraction) {
			case MAFIA: g_NameOfFraction = PRIEST;
			case PRIEST: g_NameOfFraction = AGENT;
			case AGENT: g_NameOfFraction = BARMAN;
			case BARMAN: g_NameOfFraction = HUNTER;
			case HUNTER: g_NameOfFraction = NONE;
			case NONE: g_NameOfFraction = MAFIA;
		}
	} else {
		new szIdPlayer[3], nick[33], access, callback;
		menu_item_getinfo(menu, item, access, szIdPlayer, charsmax(szIdPlayer), nick, charsmax(nick), callback);
		
		new idPlayer = str_to_num(szIdPlayer);
		get_user_name(idPlayer, nick, charsmax(nick));
		
		if(g_NameOfFraction == NONE) {
			new szText[20];
			if(is_user_mafia(idPlayer)) {
				szText = "czlonkiem Mafii";
				remove_user_mafia(idPlayer);
			} else if(idPlayer == g_Priest) {
				szText = "ksiedzem";
				g_Priest = 0;
				g_PriestVote = 0;
			} else if(idPlayer == g_Agent) {
				szText = "agentem";
				g_Agent = 0;
				g_AgentVote = 0;
			} else if(idPlayer == g_Barman) {
				szText = "barmanem";
				g_Barman = 0;
				g_BarmanVote = 0;
			} else if(idPlayer == g_Hunter) {
				szText = "lowca";
				g_Hunter = 0;
				g_HunterVote = 0;
			}
			
			ColorChat(g_GameLeader, RED, "%s ^1Zabrano funkcje graczowi. ^3%s ^1przestal byc ^3%s^1.", g_NameOfFractionPrefix, nick, szText);
			ColorChat(idPlayer, RED, "%s ^1Zabrano ci funkcje. Przestales byc ^3%s ^1i znowu jestes nikim.", g_NameOfFractionPrefix, szText);
		} else {
			new szText[20];
			switch(g_NameOfFraction) {
				case MAFIA: szText = "czlonka Mafii";
				case PRIEST: {
					szText = "ksiedza";
					g_PriestVote = idPlayer;
				}
				case AGENT: {
					szText = "agenta";
					g_AgentVote = idPlayer;
				}
				case BARMAN: {
					szText = "barmana";
					g_BarmanVote = idPlayer;
				}
				case HUNTER: {
					szText = "lowcy";
					g_HunterVote = idPlayer;
				}
			}
			
			ColorChat(g_GameLeader, RED, "%s ^3%s ^1zastanawia sie nad przyjeciem funkcji ^3%s^1.", g_NameOfFractionPrefix, nick, szText);
			ColorChat(idPlayer, RED, "%s ^1Zostales wybrany! Czy chcesz przyjac funkcje ^3%s^1?", g_NameOfFractionPrefix, szText);
			
			g_VoteTime[idPlayer] = g_TimeForVote;
			new parameters[5], szFraction[2];
			num_to_str(g_NameOfFraction, szFraction, charsmax(szFraction));
			formatex(parameters, charsmax(parameters), "%s %s", szIdPlayer, szFraction);
			set_task(1.0, "accept_fraction_menu", idPlayer + 3000, parameters, charsmax(parameters),"b");
		}
	}
	
	menu_destroy(menu);
	
	new page = item / 7;
	users_manager_menu(id, page);
	
	return PLUGIN_HANDLED;
}

public accept_fraction_menu(data[]) {
	new szId[3], szFraction[2];
	split(data, szId, charsmax(szId), szFraction, charsmax(szFraction), " ");
	
	new fraction = str_to_num(szFraction), id = str_to_num(szId);
	new szText[20], szMenuTitle[70];
	switch(fraction) {
		case MAFIA: szText = "czlonkiem Mafii";
		case PRIEST: szText = "ksiedzem";
		case AGENT: szText = "agentem";
		case BARMAN: szText = "barmanem";
		case HUNTER: szText = "lowca";
	}
	
	formatex(szMenuTitle, charsmax(szMenuTitle), "[%ds]%s Zostales wybrany! Czy chcesz zostac %s?",g_VoteTime[id], g_NameOfFractionMenuPrefix, szText);

	new acceptFractionMenu = menu_create(szMenuTitle, "accept_fraction_menu_handler");
	
	menu_additem(acceptFractionMenu, "Tak", szFraction);
	menu_additem(acceptFractionMenu, "Nie", szFraction);
	
	menu_setprop(acceptFractionMenu, MPROP_EXIT, MEXIT_NEVER);
	menu_display(id, acceptFractionMenu);
	
	g_VoteTime[id]--;
	if(g_VoteTime[id] < 0) {
		remove_task(id + 3000);
		g_VoteTime[id] = 0;
		
		new nick[33]; get_user_name(id, nick, charsmax(nick));
		switch(fraction) {
			case MAFIA: szText = "czlonka Mafii";
			case PRIEST: {
				szText = "ksiedza";
				g_PriestVote = 0;
			}
			case AGENT: {
				szText = "agenta";
				g_AgentVote = 0;
			}
			case BARMAN: {
				szText = "barmana";
				g_BarmanVote = 0;
			}
			case HUNTER: {
				szText = "lowcy";
				g_HunterVote = 0;
			}
		}
		
		ColorChat(g_GameLeader, RED, "%s ^3%s ^1spoznil sie z akceptacja funkcji ^3%s^1! Czas minal.", g_NameOfFractionPrefix, nick, szText);
		ColorChat(id, RED, "%s Czas na zaakceptowanie funkcji ^3%s ^1minal! Jestes zwyklym czlonkiem miasta.", g_NameOfFractionPrefix, szText);
		
		show_menu(id, 0, "^n", 1);
		
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_HANDLED;
}

public accept_fraction_menu_handler(id, menu, item) {
	if(item < 0) return PLUGIN_HANDLED;
	
	remove_task(id + 3000);
	g_VoteTime[id] = 0;
	
	new szFraction[2], name[10], access, callback;
	menu_item_getinfo(menu, item, access, szFraction, charsmax(szFraction), name, charsmax(name), callback);
	new fraction = str_to_num(szFraction);
	
	new msgGameLeader[100], msgPlayer[100];
	new nick[33]; get_user_name(id, nick, charsmax(nick));
	switch(item) {
		case 0: {
			switch(fraction) {
				case MAFIA: {
					formatex(msgPlayer, charsmax(msgPlayer), "%s ^1Zostales ^3mafioza^1!", g_NameOfFractionPrefix);
					formatex(msgGameLeader, charsmax(msgGameLeader), "%s ^3%s ^1zgodzil sie zostac ^3mafioza^1!", g_NameOfFractionPrefix, nick);
					add_user_mafia(id);
				}
				case PRIEST: {
					formatex(msgPlayer, charsmax(msgPlayer), "%s ^1Zostales ^3ksiedzem^1. Nie grzesz za wiele!", g_NameOfFractionPrefix);
					formatex(msgGameLeader, charsmax(msgGameLeader), "%s ^3%s ^1zgodzil sie zostac ^3ksiedzem^1!", g_NameOfFractionPrefix, nick);
					g_Priest = id;
					g_PriestVote = 0;
				}
				case AGENT: {
					formatex(msgPlayer, charsmax(msgPlayer), "%s ^1Zostales ^3agentem^1. Pokaz Mafii, kto rzadzi w tym miescie!", g_NameOfFractionPrefix);
					formatex(msgGameLeader, charsmax(msgGameLeader), "%s ^3%s ^1zgodzil sie zostac ^3agentem^1!", g_NameOfFractionPrefix, nick);
					g_Agent = id;
					g_AgentVote = 0;
				}
				case BARMAN: {
					formatex(msgPlayer, charsmax(msgPlayer), "%s ^1Zostales ^3barmanem^1. Pij madrze!", g_NameOfFractionPrefix);
					formatex(msgGameLeader, charsmax(msgGameLeader), "%s ^3%s ^1zgodzil sie zostac ^3barmanem^1!", g_NameOfFractionPrefix, nick);
					g_Barman = id;
					g_BarmanVote = 0;
				}
				case HUNTER: {
					formatex(msgPlayer, charsmax(msgPlayer), "%s ^1Zostales ^3lowca^1. Miasto nie pozbedzie sie ciebie tak szybko!", g_NameOfFractionPrefix);
					formatex(msgGameLeader, charsmax(msgGameLeader), "%s ^3%s ^1zgodzil sie zostac ^3lowca^1!", g_NameOfFractionPrefix, nick);
					g_Hunter = id;
					g_HunterVote = 0;
					g_HunterSkill = true;
				}
			}
		}
		case 1: {
			switch(fraction) {
				case MAFIA: {
					formatex(msgPlayer, charsmax(msgPlayer), "%s ^1Odrzuciles propozycje bycia ^3mafioza^1!", g_NameOfFractionPrefix);
					formatex(msgGameLeader, charsmax(msgGameLeader), "%s ^3%s ^1odrzuca propozycje bycia ^3mafioza^1!", g_NameOfFractionPrefix, nick);
				}
				case PRIEST: {
					formatex(msgPlayer, charsmax(msgPlayer), "%s ^1Odrzuciles propozycje bycia ^3ksiedzem^1!", g_NameOfFractionPrefix);
					formatex(msgGameLeader, charsmax(msgGameLeader), "%s ^3%s ^1odrzuca propozycje bycia ^3ksiedzem^1!", g_NameOfFractionPrefix, nick);
					g_PriestVote = 0;
				}
				case AGENT: {
					formatex(msgPlayer, charsmax(msgPlayer), "%s ^1Odrzuciles propozycje bycia ^3agentem^1!", g_NameOfFractionPrefix);
					formatex(msgGameLeader, charsmax(msgGameLeader), "%s ^3%s ^1odrzuca propozycje bycia ^3agentem^1!", g_NameOfFractionPrefix, nick);
					g_AgentVote = 0;
				}
				case BARMAN: {
					formatex(msgPlayer, charsmax(msgPlayer), "%s ^1Odrzuciles propozycje bycia ^3barmanem^1!", g_NameOfFractionPrefix);
					formatex(msgGameLeader, charsmax(msgGameLeader), "%s ^3%s ^1odrzuca propozycje bycia ^3barmanem^1!", g_NameOfFractionPrefix, nick);
					g_BarmanVote = 0;
				}
				case HUNTER: {
					formatex(msgPlayer, charsmax(msgPlayer), "%s ^1Odrzuciles propozycje bycia ^3lowca^1!", g_NameOfFractionPrefix);
					formatex(msgGameLeader, charsmax(msgGameLeader), "%s ^3%s ^1odrzuca propozycje bycia ^3lowca^1!", g_NameOfFractionPrefix, nick);
					g_HunterVote = 0;
				}
			}
		}
	}
	ColorChat(g_GameLeader, RED, msgGameLeader);
	ColorChat(id, RED, msgPlayer);
	if(is_user_mafia(id)) ColorChat(id, RED, "%s ^1Komenda^3 /chat tekst ^1sluzy do porozumienia sie z innymi czlonkami mafii!", g_GamePrefix);
	
	menu_destroy(menu);
	
	return PLUGIN_HANDLED;
}

public mafia_chat(id) {
	new msg[256];
	read_args(msg, charsmax(msg));
	remove_quotes(msg);
	
	if(!is_user_mafia(id)) return PLUGIN_CONTINUE;
	
	if(msg[0] == '/' && msg[1] == 'c' && msg[2] == 'h' && msg[3] == 'a' && msg[4] == 't') {
		if(!is_user_mafia(id)) return PLUGIN_HANDLED;
		
		new nick[33]; get_user_name(id, nick, charsmax(nick));
		
		new players[32], playersNumber; get_players(players, playersNumber);
		for(new i = 0;i < playersNumber; i++) {
			new idPlayer = players[i];
			
			if(is_user_mafia(idPlayer)) ColorChat(idPlayer, RED, "%s ^3%s ^1: %s", g_MafiaChatPrefix, nick, msg[5]);
		}
		
		ColorChat(g_GameLeader, RED, "%s ^3%s ^1: %s", g_MafiaChatPrefix, nick, msg[5]);
		
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public players_menu(data[]) {
	new id = str_to_num(data);
	
	new m1, m2, page;
	player_menu_info(id, m1, m2, page);
	
	new szMenuTitle[60], handler[30];
	switch(g_TypeOfDay) {
		case CITY_VOTE: {
			formatex(szMenuTitle, charsmax(szMenuTitle), "[%ds] %s \wWybierz osobe do zabicia", g_VoteTime[id], g_CityVoteMenuPrefix);
			handler = "city_vote_handler";
		}
		case HUNTER_VOTE: {
			formatex(szMenuTitle, charsmax(szMenuTitle), "[%ds] %s \wWybierz osobe do zabicia", g_VoteTime[id], g_HunterVoteMenuPrefix);
			handler = "single_vote_handler";
		}
		case MAFIA_VOTE: {
			formatex(szMenuTitle, charsmax(szMenuTitle), "[%ds] %s \wWybierz osobe do zabicia", g_VoteTime[id], g_MafiaVoteMenuPrefix);
			handler = "mafia_vote_handler";
		}
		case PRIEST_VOTE: {
			formatex(szMenuTitle, charsmax(szMenuTitle), "[%ds] %s \wWybierz osobe do modlitwy", g_VoteTime[id], g_PriestVoteMenuPrefix);
			handler = "single_vote_handler";
		}
		case AGENT_VOTE: {
			formatex(szMenuTitle, charsmax(szMenuTitle), "[%ds] %s \wWybierz osobe do sprawdzenia", g_VoteTime[id], g_AgentVoteMenuPrefix);
			handler = "single_vote_handler";
		}
		case BARMAN_VOTE: {
			formatex(szMenuTitle, charsmax(szMenuTitle), "[%ds] %s \wWybierz osobe do upicia", g_VoteTime[id], g_BarmanVoteMenuPrefix);
			handler = "single_vote_handler";
		}
	}

	new playersMenu = menu_create(szMenuTitle, handler);
	
	new players[32], playersNumber; get_players(players, playersNumber);
	for(new i = 0; i < playersNumber; i++) {
		new idPlayer = players[i];
		
		if(!is_user_playing(idPlayer)) continue;
		
		new szIdPlayer[3]; num_to_str(idPlayer, szIdPlayer, charsmax(szIdPlayer));
		new nick[33]; get_user_name(idPlayer, nick, charsmax(nick));
		menu_additem(playersMenu, nick, szIdPlayer);
	}
	
	menu_setprop(playersMenu, MPROP_EXIT, MEXIT_NEVER);
	menu_setprop(playersMenu, MPROP_BACKNAME, "Poprzednia strona");
	menu_setprop(playersMenu, MPROP_NEXTNAME, "Nastepna strona");
	menu_display(id, playersMenu, page);
	
	g_VoteTime[id]--;
	if(g_VoteTime[id] < 0) {
		remove_task(id + 3000);
		g_VoteTime[id] = 0;
		
		show_menu(id, 0, "^n", 1);
		
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_HANDLED;
}

stock players_count(){
	new iIle = 0;

	for(new i = 1; i < get_maxplayers(); i++){
		if(!is_user_connected(i))
			continue;

		if(is_user_playing(i))
			iIle++;
	}
	
	return iIle;
}

public stop_user_tasks(id) {
	if(task_exists(id + 500)) remove_task(id + 500);
	if(task_exists(id + 3000)) remove_task(id + 3000);
	show_menu(id, 0, "^n", 1);
}

public stop_game_tasks() {
	for(new i = 1000; i < 1009; i++) {
		if(task_exists(i)) remove_task(i);
	}
	
	if(task_exists(2000)) remove_task(2000);
	if(task_exists(5000)) remove_task(5000);
}

public is_user_admin_mafia(id) {
	return (is_user_alive(id) && get_user_team(id) == 2 && (get_user_flags(id) & ADMIN_MAFIA));
}

public is_user_playing(id) {
	return (is_user_alive(id) && get_user_team(id) == 1);
}

public is_user_mafia(id) {
	for(new i = 0; i < ArraySize(g_Mafia); i++) {
		if(id == ArrayGetCell(g_Mafia, i)) return true;
	}
	return false;
}

public remove_user_mafia(id) {
	for(new i = 0; i < ArraySize(g_Mafia); i++) {
		if(id == ArrayGetCell(g_Mafia, i)) {
			ArrayDeleteItem(g_Mafia, i);
			return;
		}
	}
}

public add_user_mafia(id) {
	ArrayPushCell(g_Mafia, id);
}

public client_infochanged(id){
	new newname[32], oldname[32];
	get_user_info(id, "name", newname, 31);
	get_user_name(id, oldname, 31);
	if(!equal(oldname, newname)){
		set_user_info(id,"name",oldname);
		ColorChat(id, GREEN, "%s ^1Zakaz zmiany nicku podczas zabawy!", g_GamePrefix)
		return PLUGIN_HANDLED;
	}
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1045\\ f0\\ fs16 \n\\ par }
*/
