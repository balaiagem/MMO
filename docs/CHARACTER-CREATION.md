# Fichas e progressão 5e

Entrada local: http://localhost:8080/characters.html. O criador continua oferecendo Guerreiro, Ladino, Clérigo do Domínio da Vida e Mago; Humano, Alto Elfo, Anão da Colina e Halfling Pés-Leves. Os personagens começam no nível 1 em Rookgaard. A ficha é salva em `dnd_characters`; storages do servidor são a fonte de verdade para atributos e progressão durante o jogo.

## Progressão disponível

XP D&D é independente da experiência de Tibia e fica no storage 95004. Ratos concedem 10 XP. Os marcos são nível 2: 300 XP; nível 3: 900; nível 4: 2.700; nível 5: 6.500. O nível D&D persistido fica no storage 95003 e determina proficiência, escalonamento de truques, ataques extras, PV máximos e espaços de magia. A interface de magia libera opções por classe e nível.

Benefícios programados até o nível 5: Guerreiro ganha Surto de Ação no 2, Campeão/Critico Aprimorado no 3 e Ataque Extra no 5; Ladino ganha Ação Ardilosa no 2, Ladino/Ladrao no 3, Sneak Attack 2d6 no 3 e 3d6 no 5, e Esquiva Sobrenatural no 5; Clérigo ganha Canalizar Divindade no 2, espaços de magia de 2º círculo no 3 e Destruir Mortos-Vivos no 5; Mago ganha Evocação no 2, espaços de 2º círculo no 3 e de 3º no 5. Proficiência aumenta no 5; PV usam o valor médio do dado de vida por nível, modificador de Constituição e Robustez Anã.

Ao atingir o nível 4, escolha no chat `/levelup str+2`, `/levelup str+1,dex+1`, `/levelup tough` ou `/levelup resilient str` (troque o atributo entre str, dex, con, int, wis e cha). Resiliente concede +1 no atributo e proficiência na salvaguarda escolhida; Tough acrescenta 2 PV máximos por nível. A escolha fica pendente até ser registrada. A implementação ainda não oferece todos os talentos publicados nem a lista completa de escolhas de perícias, estilo de luta, equipamento e magias; hoje essas partes iniciais permanecem nos modelos de criação existentes. Recursos de classe que aparecem na ficha ainda não estão todos ligados a comandos/efeitos de combate.

Espaços de magia de Clérigo/Mago seguem a tabela de conjurador completo nos níveis 1–5 e são separados por círculo nos storages 95030–95032. O protocolo nativo de mana transporta a soma para as barras do cliente; a ficha mostra cada círculo. Descanso e preparação/seleção completa de magias ainda estão pendentes. O Assign Spell mantém as magias anteriores e libera Scorching Ray/Spiritual Weapon no nível 3 e Fireball/Mass Healing Word no nível 5. O combate ainda usa uma adaptação simples para alvos/área e não cobre todos os detalhes de alcance, concentração, salvaguardas e aliados de 5e.

## Personagem GM

Foi criado `Mestre GM` na conta local `admin` (senha `admin`), com grupo QA próprio e acesso aos comandos de teste. Digite `/gm help` no jogo. A lista completa está em [COMANDOS-GM.txt](../COMANDOS-GM.txt). O GM pode curar, definir XP/nível, restaurar espaços, criar um rato, reiniciar progresso D&D e teleportar para coordenadas. O grupo bloqueia ataque entre jogadores e permite testar ataques e magias nos monstros.

## Fonte das regras

O recorte de classes, níveis e magias usa o SRD 5.1 (2014), publicado sob CC-BY 4.0: [SRD 5.1 oficial](https://media.dndbeyond.com/compendium-images/srd/5.1/SRD-OGL_V5.1.pdf). A criação e os conteúdos de classe ainda precisam completar as escolhas de personagem previstas no [plano mestre](MASTER-DEVELOPMENT-PLAN.md); não são uma implementação integral de todo o Player’s Handbook.
