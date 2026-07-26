import { lazy, Suspense, useEffect } from 'react';
import type { JSX } from 'react';

import { useAppContext } from './app-context';
import {
    detachPromise,
    formatCountdown,
    isTutorialComplete,
} from './lib/app-helpers';

const AccountScreen = lazy(async () => {
    const module = await import('./components/menu/AccountScreen');
    return { default: module.AccountScreen };
});
const AuthScreen = lazy(async () => {
    const module = await import('./components/menu/AuthScreen');
    return { default: module.AuthScreen };
});
const FriendsScreen = lazy(async () => {
    const module = await import('./components/menu/FriendsScreen');
    return { default: module.FriendsScreen };
});
const LeaderboardScreen = lazy(async () => {
    const module = await import('./components/menu/LeaderboardScreen');
    return { default: module.LeaderboardScreen };
});
const MenuScreen = lazy(async () => {
    const module = await import('./components/menu/MenuScreen');
    return { default: module.MenuScreen };
});
const MultiplayerGameScreen = lazy(async () => {
    const module = await import('./components/game/MultiplayerGameScreen');
    return { default: module.MultiplayerGameScreen };
});
const OpponentPickerScreen = lazy(async () => {
    const module = await import('./components/menu/OpponentPickerScreen');
    return { default: module.OpponentPickerScreen };
});
const SingleGameScreen = lazy(async () => {
    const module = await import('./components/game/SingleGameScreen');
    return { default: module.SingleGameScreen };
});
const SoloPregameScreen = lazy(async () => {
    const module = await import('./components/menu/SoloPregameScreen');
    return { default: module.SoloPregameScreen };
});
const LandingPage = lazy(async () => {
    const module = await import('./components/website/LandingPage');
    return { default: module.LandingPage };
});
const PrivacyPage = lazy(async () => {
    const module = await import('./components/website/PrivacyPage');
    return { default: module.PrivacyPage };
});
const SupportPage = lazy(async () => {
    const module = await import('./components/website/SupportPage');
    return { default: module.SupportPage };
});

function MenuPage(): JSX.Element {
    const {
        session,
        isGuest,
        localCpuGame,
        multiplayerGame,
        navigateTo,
        playerLevel,
    } = useAppContext();
    const needsTutorial = !isTutorialComplete();

    const toastId = localCpuGame.isInRoom ? 0 : multiplayerGame.lobbyToast.id;
    const toastMessage = localCpuGame.isInRoom
        ? undefined
        : multiplayerGame.lobbyToast.message;

    return (
        <MenuScreen
            isGuest={isGuest || !session}
            needsTutorial={needsTutorial}
            onOpenAccount={() => {
                navigateTo('/app/account');
            }}
            onOpenAuth={() => {
                navigateTo('/app/login');
            }}
            onOpenBattle={() => {
                navigateTo('/app/battle');
            }}
            onOpenFriends={() => {
                navigateTo('/app/friends');
            }}
            onOpenLeaderboard={() => {
                navigateTo('/app/leaderboard');
            }}
            onOpenSolo={() => {
                navigateTo('/app/solo');
            }}
            onOpenTutorial={() => {
                navigateTo('/app/tutorial');
            }}
            playerLevel={playerLevel}
            toastId={toastId}
            toastMessage={toastMessage}
        />
    );
}

function TutorialPage(): JSX.Element {
    const { tutorialGame, handleTutorialReturn } = useAppContext();

    return (
        <MultiplayerGameScreen
            currentMultiplayerPlayer={tutorialGame.currentMultiplayerPlayer}
            isMultiplayerComboRunning={tutorialGame.isMultiplayerComboRunning}
            isMultiplayerInputDisabled={tutorialGame.isMultiplayerInputDisabled}
            multiplayerInputResetKey={tutorialGame.multiplayerInputResetKey}
            multiplayerPrimeQueue={tutorialGame.multiplayerPrimeQueue}
            multiplayerSnapshot={tutorialGame.multiplayerSnapshot}
            onAllowCpuAttack={tutorialGame.allowCpuAttack}
            onBack={handleTutorialReturn}
            onSubmit={tutorialGame.handleMultiplayerComboSubmit}
            onTutorialComplete={tutorialGame.notifyTutorialDone}
            playablePrimes={tutorialGame.playablePrimes}
            tutorialMode
        />
    );
}

function SoloPregamePage(): JSX.Element {
    const { soloGame, navigateTo } = useAppContext();

    return (
        <SoloPregameScreen
            bestScore={soloGame.bestScore}
            onBack={() => {
                navigateTo('/app');
            }}
            onStart={() => {
                soloGame.startSingleGame();
            }}
        />
    );
}

function SoloPlayPage(): JSX.Element {
    const { soloGame, returnToMenu } = useAppContext();

    return (
        <SingleGameScreen
            bestScore={soloGame.bestScore}
            formatCountdown={formatCountdown}
            isNewBest={soloGame.isNewBest}
            isPaused={soloGame.isPaused}
            isSoloComboRunning={soloGame.isSoloComboRunning}
            onBack={returnToMenu}
            onPause={soloGame.pause}
            onResume={soloGame.resume}
            onRetry={soloGame.startSingleGame}
            onSubmit={soloGame.handleSoloComboSubmit}
            playablePrimes={soloGame.playablePrimes}
            soloCountdownProgress={soloGame.soloCountdownProgress}
            soloInputResetKey={soloGame.soloInputResetKey}
            soloPrimeQueue={soloGame.soloPrimeQueue}
            soloStageAdvanceSolvedStateKey={
                soloGame.soloStageAdvanceSolvedStateKey
            }
            soloState={soloGame.soloState}
            soloTimeLeft={soloGame.soloTimeLeft}
            soloTimerPenaltyPopKey={soloGame.soloTimerPenaltyPopKey}
        />
    );
}

function BattlePickerPage(): JSX.Element {
    const { localCpuGame, multiplayerGame, navigateTo, playerName } =
        useAppContext();

    const activeMenuGame = localCpuGame.isInRoom
        ? {
              isCpuOpponent: true,
              isCurrentPlayerReady: localCpuGame.isCurrentPlayerReady,
              isInRoom: localCpuGame.isInRoom,
              isOpponentReady: localCpuGame.isOpponentReady,
              onToggleReady: localCpuGame.toggleReady,
              opponentName: localCpuGame.opponentName,
          }
        : {
              isCpuOpponent: false,
              isCurrentPlayerReady: multiplayerGame.isCurrentPlayerReady,
              isInRoom: multiplayerGame.isInRoom,
              isOpponentReady: multiplayerGame.isOpponentReady,
              onToggleReady: multiplayerGame.toggleReady,
              opponentName: multiplayerGame.opponentName,
          };

    return (
        <OpponentPickerScreen
            isCpuOpponent={activeMenuGame.isCpuOpponent}
            isCurrentPlayerReady={activeMenuGame.isCurrentPlayerReady}
            isInRoom={activeMenuGame.isInRoom}
            isOpponentReady={activeMenuGame.isOpponentReady}
            onBack={() => {
                navigateTo('/app');
            }}
            onInvitePlayer={(targetPlayerId) => {
                detachPromise(
                    multiplayerGame.handleLobbyInvite(targetPlayerId)
                );
            }}
            onLeaveVs={() => {
                localCpuGame.resetLocalCpuGame();
                detachPromise(multiplayerGame.resetMultiplayerGame());
            }}
            onlineUsers={multiplayerGame.onlineUsers}
            onPrefetchInviteUsers={multiplayerGame.prefetchOnlineUsers}
            onStartCpuGame={() => {
                localCpuGame.startLocalCpuGame();
            }}
            onToggleReady={() => {
                detachPromise(Promise.resolve(activeMenuGame.onToggleReady()));
            }}
            opponentName={activeMenuGame.opponentName}
            playerName={playerName}
        />
    );
}

function BattlePlayPage(): JSX.Element {
    const { localCpuGame, multiplayerGame, returnToMenu } = useAppContext();

    const activeBattleGame = localCpuGame.isLocalCpuGameActive
        ? {
              currentMultiplayerPlayer: localCpuGame.currentMultiplayerPlayer,
              isMultiplayerComboRunning: localCpuGame.isMultiplayerComboRunning,
              isMultiplayerInputDisabled:
                  localCpuGame.isMultiplayerInputDisabled,
              multiplayerInputResetKey: localCpuGame.multiplayerInputResetKey,
              multiplayerPrimeQueue: localCpuGame.multiplayerPrimeQueue,
              multiplayerSnapshot: localCpuGame.multiplayerSnapshot,
              onRematch: localCpuGame.rematchLocalCpuGame,
              onSubmit: localCpuGame.handleMultiplayerComboSubmit,
              playablePrimes: localCpuGame.playablePrimes,
          }
        : {
              currentMultiplayerPlayer:
                  multiplayerGame.currentMultiplayerPlayer,
              isMultiplayerComboRunning:
                  multiplayerGame.isMultiplayerComboRunning,
              isMultiplayerInputDisabled:
                  multiplayerGame.isMultiplayerInputDisabled,
              multiplayerInputResetKey:
                  multiplayerGame.multiplayerInputResetKey,
              multiplayerPrimeQueue: multiplayerGame.multiplayerPrimeQueue,
              multiplayerSnapshot: multiplayerGame.multiplayer.snapshot,
              onRematch: undefined,
              onSubmit: multiplayerGame.handleMultiplayerComboSubmit,
              playablePrimes: multiplayerGame.playablePrimes,
          };

    return (
        <MultiplayerGameScreen
            currentMultiplayerPlayer={activeBattleGame.currentMultiplayerPlayer}
            isMultiplayerComboRunning={
                activeBattleGame.isMultiplayerComboRunning
            }
            isMultiplayerInputDisabled={
                activeBattleGame.isMultiplayerInputDisabled
            }
            multiplayerInputResetKey={activeBattleGame.multiplayerInputResetKey}
            multiplayerPrimeQueue={activeBattleGame.multiplayerPrimeQueue}
            multiplayerSnapshot={activeBattleGame.multiplayerSnapshot}
            onBack={returnToMenu}
            onRematch={activeBattleGame.onRematch}
            onSubmit={activeBattleGame.onSubmit}
            playablePrimes={activeBattleGame.playablePrimes}
        />
    );
}

function LoginPage(): JSX.Element | undefined {
    const { navigateTo, session } = useAppContext();

    useEffect(() => {
        if (session) {
            navigateTo('/app');
        }
    }, [session, navigateTo]);

    if (session) {
        return undefined;
    }

    return (
        <AuthScreen
            initialMode='login'
            onAuthSuccess={() => {
                navigateTo('/app');
            }}
            onBack={() => {
                navigateTo('/app');
            }}
        />
    );
}

function SignupPage(): JSX.Element | undefined {
    const { navigateTo, session } = useAppContext();

    useEffect(() => {
        if (session) {
            navigateTo('/app');
        }
    }, [session, navigateTo]);

    if (session) {
        return undefined;
    }

    return (
        <AuthScreen
            initialMode='signup'
            onAuthSuccess={() => {
                navigateTo('/app');
            }}
            onBack={() => {
                navigateTo('/app');
            }}
        />
    );
}

function AccountPage(): JSX.Element | undefined {
    const { handleEditName, handleLogout, navigateTo, playerName, session } =
        useAppContext();

    useEffect(() => {
        if (!session) {
            navigateTo('/app');
        }
    }, [session, navigateTo]);

    if (!session) {
        return undefined;
    }

    return (
        <AccountScreen
            onBack={() => {
                navigateTo('/app');
            }}
            onEditName={handleEditName}
            onLogout={() => {
                handleLogout();
                navigateTo('/app');
            }}
            playerName={playerName}
            userId={session.user.id}
        />
    );
}

function FriendsPage(): JSX.Element | undefined {
    const { navigateTo, playerName, session } = useAppContext();

    useEffect(() => {
        if (!session) {
            navigateTo('/app');
        }
    }, [session, navigateTo]);

    if (!session) {
        return undefined;
    }

    return (
        <FriendsScreen
            onBack={() => {
                navigateTo('/app');
            }}
            playerName={playerName}
            userId={session.user.id}
        />
    );
}

function LeaderboardPage(): JSX.Element {
    const { leaderboardData, navigateTo, playerName } = useAppContext();

    return (
        <LeaderboardScreen
            onBack={() => {
                navigateTo('/app');
            }}
            playerName={playerName}
            prefetchedData={leaderboardData}
        />
    );
}

function ResolvedRoute(): JSX.Element {
    const { pathname } = useAppContext();

    switch (pathname) {
        case '/': {
            return <LandingPage />;
        }

        case '/privacy': {
            return <PrivacyPage />;
        }

        case '/support': {
            return <SupportPage />;
        }

        case '/app/tutorial': {
            return <TutorialPage />;
        }

        case '/app/solo': {
            return <SoloPregamePage />;
        }

        case '/app/solo/play': {
            return <SoloPlayPage />;
        }

        case '/app/battle': {
            return <BattlePickerPage />;
        }

        case '/app/battle/play': {
            return <BattlePlayPage />;
        }

        case '/app/login': {
            return <LoginPage />;
        }

        case '/app/signup': {
            return <SignupPage />;
        }

        case '/app/account': {
            return <AccountPage />;
        }

        case '/app/friends': {
            return <FriendsPage />;
        }

        case '/app/leaderboard': {
            return <LeaderboardPage />;
        }

        default: {
            return <MenuPage />;
        }
    }
}

export function AppRoutes(): JSX.Element {
    return (
        <Suspense fallback={undefined}>
            <ResolvedRoute />
        </Suspense>
    );
}

export { isTutorialComplete } from './lib/app-helpers';
