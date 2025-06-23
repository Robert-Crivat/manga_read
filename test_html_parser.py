from bs4 import BeautifulSoup
import requests
import json
import time
import os

def extract_image_url(img_element):
    """Estrai l'URL dell'immagine dagli attributi dell'elemento img."""
    image_url = None
    
    # Prima controlla src se non è base64
    if img_element.has_attr('src') and not img_element['src'].startswith('data:'):
        image_url = img_element['src']
    # Se src non è utilizzabile, controlla data-src
    elif img_element.has_attr('data-src'):
        image_url = img_element['data-src']
    # Come ultimo fallback, controlla data-original
    elif img_element.has_attr('data-original'):
        image_url = img_element['data-original']
        
    # Assicurati che l'URL sia completo
    if image_url and image_url.startswith('/'):
        image_url = f"https://novelfire.net{image_url}"
        
    return image_url

def extract_novels_from_page(page_number):
    """Estrae tutte le novel da una pagina specifica."""
    url = f'https://novelfire.net/genre-all/sort-new/status-all/all-novel?page={page_number}'
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
    }
    
    try:
        response = requests.get(url, headers=headers)
        
        if response.status_code != 200:
            print(f"Errore nel download della pagina {page_number}: HTTP {response.status_code}")
            return []
            
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Trova il contenitore delle novel
        novel_list_div = soup.find('div', {'id': 'list-novel'})
        if not novel_list_div:
            print(f"Div list-novel non trovato nella pagina {page_number}!")
            return []
            
        novel_lists = novel_list_div.find_all('ul', {'class': 'novel-list'})
        if not novel_lists:
            print(f"Nessuna ul novel-list trovata nella pagina {page_number}!")
            return []
        
        # Estrai tutte le novel
        novels = []
        novel_items = []
        
        for novel_list in novel_lists:
            items = novel_list.find_all('li', {'class': 'novel-item'})
            novel_items.extend(items)
        
        print(f"Pagina {page_number}: Trovati {len(novel_items)} elementi novel-item")
        
        for item in novel_items:
            novel_info = {}
            
            # Estrai titolo e URL
            title_elem = item.find('a', {'title': True})
            if title_elem:
                novel_info['title'] = title_elem.get('title', '').strip()
                novel_info['url'] = title_elem.get('href', '')
                # Assicura che l'URL sia completo
                if novel_info['url'] and novel_info['url'].startswith('/'):
                    novel_info['url'] = f"https://novelfire.net{novel_info['url']}"
            
            # Estrai l'immagine di copertina
            cover_img = item.select_one('figure.novel-cover img')
            if cover_img:
                image_url = extract_image_url(cover_img)
                if image_url:
                    novel_info['cover_image'] = image_url
            
            # Estrai il numero di capitoli
            chapters_elem = item.select_one('div.novel-stats i.icon-book-open')
            if chapters_elem and chapters_elem.parent:
                chapters_text = chapters_elem.parent.get_text(strip=True)
                # Estrai solo i numeri
                import re
                chapter_match = re.search(r'(\d+)\s*Chapters', chapters_text)
                if chapter_match:
                    novel_info['chapters_count'] = int(chapter_match.group(1))
                else:
                    novel_info['chapters_count'] = chapters_text
            
            # Aggiungi alla lista solo se abbiamo almeno titolo e URL
            if novel_info.get('title') and novel_info.get('url'):
                novels.append(novel_info)
        
        return novels
        
    except Exception as e:
        print(f"Errore durante l'elaborazione della pagina {page_number}: {str(e)}")
        return []

def extract_all_novels(start_page=1, end_page=448, save_interval=10):
    """Estrae tutte le novel da tutte le pagine e le salva in un file JSON."""
    all_novels = []
    
    # Crea directory per i risultati se non esiste
    os.makedirs('novel_data', exist_ok=True)
    
    # Itera attraverso tutte le pagine
    for page in range(start_page, end_page + 1):
        print(f"Elaborazione pagina {page}/{end_page}...")
        page_novels = extract_novels_from_page(page)
        all_novels.extend(page_novels)
        
        # Salva i risultati parziali ogni save_interval pagine
        if page % save_interval == 0 or page == end_page:
            # Salva i risultati in JSON
            with open(f'novel_data/novels_page_{start_page}_to_{page}.json', 'w', encoding='utf-8') as f:
                json.dump({
                    "total": len(all_novels),
                    "novels": all_novels
                }, f, ensure_ascii=False, indent=2)
            
            print(f"Salvate {len(all_novels)} novel fino alla pagina {page}.")
        
        # Piccola pausa per non sovraccaricare il server
        time.sleep(1)
    
    print(f"Estrazione completata! Raccolte {len(all_novels)} novel in totale.")
    return all_novels

def extract_novel_sample():
    """Estrae alcune novel come campione (ad esempio le prime 10 pagine)."""
    return extract_all_novels(start_page=1, end_page=10, save_interval=5)

def analyze_html_structure():
    """Analizza la struttura HTML di una novel specifica per debug."""
    url = 'https://novelfire.net/genre-all/sort-new/status-all/all-novel'
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
    }
    
    response = requests.get(url, headers=headers)
    
    if response.status_code != 200:
        print(f"Errore nel download: {response.status_code}")
        return
        
    soup = BeautifulSoup(response.content, 'html.parser')
    
    # Trova il contenitore delle novel
    novel_list_div = soup.find('div', {'id': 'list-novel'})
    if not novel_list_div:
        print("Div list-novel non trovato!")
        return
        
    novel_lists = novel_list_div.find_all('ul', {'class': 'novel-list'})
    if not novel_lists:
        print("Nessuna ul novel-list trovata!")
        return
        
    print(f"Trovate {len(novel_lists)} liste di novel")
    
    # Cerca gli elementi novel-item
    novel_items = []
    for novel_list in novel_lists:
        items = novel_list.find_all('li', {'class': 'novel-item'})
        novel_items.extend(items)
    
    print(f"Trovati {len(novel_items)} elementi novel-item")
    
    # Cerca "One Piece: New Order" o prendi il primo elemento
    target_novel = None
    for item in novel_items:
        title_elem = item.find('a', {'title': True})
        if title_elem and "One Piece: New Order" in title_elem.get('title', ''):
            target_novel = item
            print("Trovata la novel 'One Piece: New Order'!")
            break
    
    if not target_novel and novel_items:
        target_novel = novel_items[0]
        title_elem = target_novel.find('a', {'title': True})
        if title_elem:
            print(f"Usando la prima novel: '{title_elem.get('title', 'Sconosciuto')}'")
    
    if not target_novel:
        print("Nessuna novel trovata!")
        return
    
    # Analizza la struttura dell'immagine di copertina
    cover_img = target_novel.select_one('figure.novel-cover img')
    if not cover_img:
        print("Immagine di copertina non trovata!")
        return
        
    print("Attributi dell'immagine di copertina:")
    for attr, value in cover_img.attrs.items():
        print(f"  {attr}: {value}")
    
    # Estrai l'URL dell'immagine in base alla priorità
    image_url = extract_image_url(cover_img)
    if image_url:
        print(f"URL dell'immagine estratto: {image_url}")
    else:
        print("Nessun URL di immagine trovato!")
    
    # Stampa l'HTML completo dell'elemento novel-item
    print("\nHTML completo dell'elemento novel-item:")
    print(target_novel.prettify())

if __name__ == "__main__":
    print("Cosa vuoi fare?")
    print("1. Analizzare la struttura HTML di una pagina specifica")
    print("2. Estrarre un campione di novel (10 pagine)")
    print("3. Estrarre tutte le novel (448 pagine)")
    
    choice = input("Scelta (1, 2, 3): ").strip()
    
    if choice == '1':
        analyze_html_structure()
    elif choice == '2':
        extract_novel_sample()
    elif choice == '3':
        # Chiedi intervallo di pagine
        start_page = int(input("Pagina iniziale (default=1): ") or "1")
        end_page = int(input("Pagina finale (default=448): ") or "448")
        save_interval = int(input("Salvare ogni quante pagine? (default=10): ") or "10")
        extract_all_novels(start_page, end_page, save_interval)
    else:
        print("Scelta non valida.")
