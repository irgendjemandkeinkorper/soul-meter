# Balance combat smoke test

- Enter a fight with a party of at least two. Expect every living member to receive one turn before the enemy acts.
- Use **Defining Strike**. Expect Soul to drop by 3 and the gauge to move 25 points toward Order.
- Use **Paradox Strike**. Expect Soul to drop by 3 and the gauge to move 25 points toward Chaos.
- Push either alignment past 60 and use its matching strike. Expect it to deal more damage than it did near equilibrium.
- Use ordinary **Strike** or **Guard** away from center. Expect the gauge to move 10 points toward equilibrium.
- Use **Stabilize** away from center. Expect the gauge to move 30 points toward equilibrium and the actor to guard.
- Fight the Bog Wight. Expect its turns to push toward Order; fight the Loam-Maddened Boar and expect Chaos pressure.
- In a multi-enemy encounter, change the selected target and attack. Expect only that target to take damage.
- Flee after taking damage. Expect current party HP to remain reduced after returning to the field and after saving/loading.
- Win an encounter. Expect its defeated flag, reputation consequence, and renown reward exactly once.
- At the Mustered Bloodbellow, confirm **Speak Its Muster-Name** is locked until Order +50 and 3 Soul, then resolves as `named`.
- On a fresh run, survive one full enemy round, hold Balance from -20 to +20, and confirm **Release the Bound Soldier** resolves as `released`.
- On a fresh run, reduce it to 0 HP and confirm the conventional outcome is `slain`.
- Lose once. Expect every party member restored to 50% max HP with no completion/reward; flee once and expect current wounds with no completion/reward.
