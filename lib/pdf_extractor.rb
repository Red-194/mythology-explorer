ILLUSTRATION_PAGES = [
  28, 30, 34, 38, 42, 46, 50, 52, 58, 62,
  70, 80, 96, 108, 124, 134, 138, 146, 150,
  166, 188, 228, 272, 286, 304, 314, 326,
  334, 350, 370, 376
]

EXTRACTED_ILLUSTRATIONS = [
  { title: "Uzume awakens the Curiosity of Ama-terasu", page: 28 },
  { title: "Susa-no-o and Kushi-nada-hime", page: 30 },
  { title: "Hoori and the Sea God's Daughter", page: 34 },
  { title: "Yorimasa slays the Vampire", page: 38 },
  { title: "Yorimasa and Benkei attacked by a ghostly company of the Taira Clan", page: 42 },
  { title: "Raiko and the Enchanted Maiden", page: 46 },
  { title: "Raiko slays the Goblin of Oyeyama", page: 50 },
  { title: "Prince Yamato and Takeru", page: 52 },
  { title: "Momotaro and the Pheasant", page: 58 },
  { title: "Hidesato and the Centipede", page: 62 },
  { title: "The Moonfolk demand the Lady Kaguya", page: 76 },
  { title: "Buddha and the Dragon", page: 80 },
  { title: "The Mikado and the Jewel Maiden", page: 96 },
  { title: "Jizō", page: 108 },
  { title: "A Kakemono Ghost", page: 124 },
  { title: "Sengen, the Goddess of Mount Fuji", page: 134 },
  { title: "Visu on Mount Fuji-Yama", page: 138 },
  { title: "Kiyo and the Priest", page: 146 },
  { title: "Yuki-Onna, the Lady of the Snow", page: 150 },
  { title: "Shingé and Yoshisawa by the Violet Well", page: 166 },
  { title: "Matsu rescues Teoyo", page: 188 },
  { title: "Shinzaburō recognised Tsuyu and her maid Yoné", page: 228 },
  { title: "The Jelly-Fish and the Monkey", page: 272 },
  { title: "The Firefly Battle", page: 286 },
  { title: "Hōïchi-the-Earless", page: 304 },
  { title: "The Maiden of Unai", page: 314 },
  { title: "Urashima and the Sea King's Daughter", page: 326 },
  { title: "Tokoyo and the Sea Serpent", page: 334 },
  { title: "The Kappa and his Victim", page: 350 },
  { title: "Kato Sayemon in his Palace of the Shōgun Ashikaga", page: 370 },
  { title: "Tōtarō and Samébito", page: 376 }
]

require "pdf-reader"

class PdfExtractor
  def self.page_text(pdf_path, page_number)
    reader = PDF::Reader.new(pdf_path)
    page = reader.pages[page_number - 1]
    page.text
  end
end
