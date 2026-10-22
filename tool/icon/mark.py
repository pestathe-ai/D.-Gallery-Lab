BLU="#1D3A8A"; ARANCIO="#F28C38"; CARTA="#FFF8F0"; PIEGA="#C96E22"

def house(fill_body=CARTA, roof=ARANCIO, fold=PIEGA, sym=BLU, dot=ARANCIO):
    return f'''
  <!-- casa-documento -->
  <path d="M28 50 L54 28 L80 50 V84 Q80 89 75 89 H33 Q28 89 28 84 Z" fill="{fill_body}"/>
  <!-- tetto arancio, piegato come l'angolo di un foglio -->
  <path d="M20 52 L54 22 L88 52 L82 57 L54 33 L26 57 Z" fill="{roof}"/>
  <path d="M82 57 L88 52 L88 60 Z" fill="{fold}"/>
  <!-- simbolo: foto con montagne e sole -->
  <rect x="35.5" y="55.5" width="37" height="27" rx="3.5" fill="none" stroke="{sym}" stroke-width="3.4"/>
  <path d="M38 80 L48.5 67 L55.5 74 L60 69.5 L70 80 Z" fill="{sym}"/>
  <circle cx="64" cy="62.5" r="3.4" fill="{sym}"/>
  <!-- puntino -->
  <circle cx="90" cy="90" r="4.5" fill="{dot}"/>'''

def full():
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108"><rect width="108" height="108" rx="26" fill="{BLU}"/>{house()}</svg>'

def fg(mono=False):
    g = house("#FFFFFF","#FFFFFF","#FFFFFF","#000000","#FFFFFF") if mono else house()
    if mono:  # simbolo "bucato" nella sagoma: maschera
        return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108"><defs><mask id="m"><rect width="108" height="108" fill="#fff"/>
  <rect x="35.5" y="55.5" width="37" height="27" rx="3.5" fill="none" stroke="#000" stroke-width="3.4"/>
  <path d="M38 80 L48.5 67 L55.5 74 L60 69.5 L70 80 Z" fill="#000"/><circle cx="64" cy="62.5" r="3.4" fill="#000"/></mask></defs>
  <g transform="translate(54 54) scale(0.8) translate(-54 -55)" mask="url(#m)"><path d="M28 50 L54 28 L80 50 V84 Q80 89 75 89 H33 Q28 89 28 84 Z" fill="#fff"/>
  <path d="M20 52 L54 22 L88 52 L82 57 L54 33 L26 57 Z" fill="#fff"/><circle cx="90" cy="90" r="4.5" fill="#fff"/></g></svg>'''
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108"><g transform="translate(54 54) scale(0.8) translate(-54 -55)">{g}</g></svg>'
