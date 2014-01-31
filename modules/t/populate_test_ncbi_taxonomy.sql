-- Copyright [2009-2014] EMBL-European Bioinformatics Institute
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

insert into ncbi_taxa_node(taxon_id,parent_id,rank,left_index,right_index) values(1,0,'superkingdom',1,24);
insert into ncbi_taxa_node(taxon_id,parent_id,rank,left_index,right_index) values(2,1,'phylum',2,11);
insert into ncbi_taxa_node(taxon_id,parent_id,rank,left_index,right_index) values(3,1,'phylum',12,23);
insert into ncbi_taxa_node(taxon_id,parent_id,rank,left_index,right_index) values(4,2,'order',3,10);
insert into ncbi_taxa_node(taxon_id,parent_id,rank,left_index,right_index) values(5,3,'order',13,20);
insert into ncbi_taxa_node(taxon_id,parent_id,rank,left_index,right_index) values(6,3,'order',21,22);
insert into ncbi_taxa_node(taxon_id,parent_id,rank,left_index,right_index) values(7,4,'species',4,5);
insert into ncbi_taxa_node(taxon_id,parent_id,rank,left_index,right_index) values(8,4,'species',6,9);
insert into ncbi_taxa_node(taxon_id,parent_id,rank,left_index,right_index) values(9,5,'species',14,19);
insert into ncbi_taxa_node(taxon_id,parent_id,rank,left_index,right_index) values(10,8,'subspecies',7,8);
insert into ncbi_taxa_node(taxon_id,parent_id,rank,left_index,right_index) values(11,9,'subspecies',15,16);
insert into ncbi_taxa_node(taxon_id,parent_id,rank,left_index,right_index) values(12,9,'subspecies',17,18);
insert into ncbi_taxa_name(taxon_id,name_class,name) values(1,'scientific name','Bacteria');
insert into ncbi_taxa_name(taxon_id,name_class,name) values(2,'scientific name','Proteobacteria');
insert into ncbi_taxa_name(taxon_id,name_class,name) values(3,'scientific name','Firmicutes');
insert into ncbi_taxa_name(taxon_id,name_class,name) values(4,'scientific name','Enterobacteriales');
insert into ncbi_taxa_name(taxon_id,name_class,name) values(5,'scientific name','Bacillales');
insert into ncbi_taxa_name(taxon_id,name_class,name) values(6,'scientific name','Lactobacillales');
insert into ncbi_taxa_name(taxon_id,name_class,name) values(7,'scientific name','Shigella dysenteriae');  
insert into ncbi_taxa_name(taxon_id,name_class,name) values(8,'scientific name','Escherichia coli');
insert into ncbi_taxa_name(taxon_id,name_class,name) values(9,'scientific name','Staphylococcus aureus ');
insert into ncbi_taxa_name(taxon_id,name_class,name) values(10,'scientific name','Escherichia coli K12');
insert into ncbi_taxa_name(taxon_id,name_class,name) values(11,'scientific name','Staphylococcus aureus 10243');
insert into ncbi_taxa_name(taxon_id,name_class,name) values(12,'scientific name','Staphylococcus aureus LAC');
