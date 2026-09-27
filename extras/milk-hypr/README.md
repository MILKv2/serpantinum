# Fork MILKv2/serpantinum — branch `milk`

`milk` = upstream `ilyamiro/serpantinum` + moje feature'y (max volume, workspace groups
per monitor) + instalator/updater wskazujacy na ten branch. Update z poziomu shella
(About → Update) ciagnie stad, wiec nie gubi feature'ow.

## Instalacja

```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/MILKv2/serpantinum/milk/install/install.sh)" && ~/.cache/serpantinum-installer/extras/milk-hypr/install.sh
```
W instalatorze wybierz **Reinstall**. Reinstall kasuje `~/.config/hypr` (kopia w
`~/.config/hypr_backup/`); `extras/milk-hypr/install.sh` przywraca z niej wlasne
`local.lua` + `monitors.lua`, dogrywa skrypty i fisha.

Aktualizacja: przycisk Update w shellu albo ta sama linijka z curlem (wtedy wybierz Update,
nie Reinstall - Update nie rusza `~/.config/hypr`).

## Dla mnie (utrzymanie)

- Nowe feature'y / PR-y zawsze od `master` (= upstream), NIGDY od `milk` — tylko
  wtedy commit z instalatorem i `extras/` nie wlezie do PR-a.
- Odswiezenie: `git checkout milk && git merge master feat/...` po rebase feature'ow.
