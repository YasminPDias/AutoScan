/// Textos de benefício por plano.
///
/// Fica em arquivo próprio porque é copy de marketing: muda com frequência e
/// não deveria exigir mexer na tela de pagamento. Quando os textos precisarem
/// mudar sem deploy, o caminho é uma coluna `beneficios jsonb` em `plano` —
/// enquanto for fixo, aqui basta.
class BeneficiosPlano {
    /// Chave = Plano.chave (PRO | PREMIUM | EMPRESARIAL | FREE).
    static const Map<String, List<String>> _porPlano = {
        'FREE': [
            '3 diagnósticos por semana',
            'Defeitos comuns e conteúdo básico',
            'Sem solução completa',
        ],
        'PRO': [
            'Diagnósticos ilimitados com solução completa',
            'Diagnóstico guiado e checklist técnico',
            'Casos reais e atualização constante',
            'Favoritos e histórico completo',
        ],
        'PREMIUM': [
            'Assessoria online e remota',
            'Esquemas elétricos e câmbios automatizados',
            'Conteúdo avançado e comunidade',
            'Precificação de mão de obra',
            'Aulas grátis no Academy',
        ],
        'EMPRESARIAL': [
            'Assessoria online e remota',
            'Esquemas elétricos e câmbios automatizados',
            'Conteúdo avançado e comunidade',
            'Precificação de mão de obra',
            'Aulas grátis no Academy',
            'Gerenciamento de equipe',
        ],
    };

    /// PREMIUM e EMPRESARIAL não repetem os itens do PRO no material original,
    /// mas presumivelmente os incluem — é o padrão de página de preço.
    /// Renderizar "Tudo do Pro, mais:" acima da lista deixa isso explícito
    /// sem inflar o card.
    ///
    /// ⚠️ CONFIRMAR: PREMIUM realmente inclui tudo do PRO?
    static const Map<String, String> _herda = {
        'PREMIUM': 'Tudo do Pro, mais:',
        'EMPRESARIAL': 'Tudo do Premium, mais:',
    };

    /// Só os itens PRÓPRIOS do plano. Use com `textoHeranca()` em telas onde
    /// o cliente JÁ escolheu — a tela de pagamento, por exemplo.
    static List<String> itens(String? chave) =>
        _porPlano[chave?.toUpperCase()] ?? const [];

    static String? textoHeranca(String? chave) => _herda[chave?.toUpperCase()];

    /// De qual plano este herda. Null = não herda de ninguém.
    static const Map<String, String> _herdaDe = {
        'PREMIUM': 'PRO',
        'EMPRESARIAL': 'PREMIUM',
    };

    /// Lista EXPANDIDA, com os itens herdados incluídos.
    ///
    /// Para telas de COMPARAÇÃO, onde os cards ficam lado a lado. Ali a
    /// herança implícita funciona contra você: se o PREMIUM não repetir
    /// "diagnósticos ilimitados", ele parece ter menos que o PRO.
    ///
    /// Resolve a cadeia inteira (EMPRESARIAL → PREMIUM → PRO) e remove
    /// duplicatas preservando a ordem.
    static List<String> itensCompletos(String? chave) {
        final k = chave?.toUpperCase();
        if (k == null || !_porPlano.containsKey(k)) return const [];

        final acumulado = <String>[];
        final visitados = <String>{};

        void coletar(String atual) {
            // Guarda contra ciclo, caso alguém edite _herdaDe sem cuidado.
            if (!visitados.add(atual)) return;
            final pai = _herdaDe[atual];
            if (pai != null) coletar(pai);
            acumulado.addAll(_porPlano[atual] ?? const []);
        }

        coletar(k);
        return acumulado.toSet().toList();
    }

    /// `maxUsuarios` vem do banco, não do texto fixo — se você mudar o limite
    /// do EMPRESARIAL, o card acompanha sozinho.
    static String limiteUsuarios(int max) => 'Até $max usuários';
}