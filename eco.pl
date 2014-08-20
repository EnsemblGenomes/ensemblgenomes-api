use strict;
use warnings;
use Bio::EnsEMBL::LookUp;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
print "Building helper\n";
my $helper = Bio::EnsEMBL::LookUp->new();

my $nom = 'escherichia_coli_str_k_12_substr_mg1655';
print "Getting DBA for $nom\n";
my ($dba) = @{$helper->get_by_name_exact($nom)};  

my $gene = $dba->get_GeneAdaptor()->fetch_by_stable_id('b0344');
print "Found gene " . $gene->external_name() . "\n";

# load compara adaptor
my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-HOST => 'mysql-eg-publicsql.ebi.ac.uk', -USER => 'anonymous', -PORT => '4157', -DBNAME => 'ensembl_compara_bacteria_23_76');
# find the corresponding member
my $member = $compara_dba->get_GeneMemberAdaptor()->fetch_by_source_stable_id('ENSEMBLGENE',$gene->stable_id());
# find families involving this member
for my $family (@{$compara_dba->get_FamilyAdaptor()->fetch_all_by_Member($member)}) {
    print "Family ".$family->stable_id()."\n";
}

#To retrieve the genes belonging to a given family:
#
# use strict;
#use warnings;
#use Bio::EnsEMBL::LookUp;
#use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
#print "Building helper\n";
#my $helper = Bio::EnsEMBL::LookUp->new();
#
## load compara adaptor
#my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-HOST => 'mysql-eg-publicsql.ebi.ac.uk', -USER => 'anonymous', -PORT => '4157', -DBNAME => 'ensembl_compara_bacteria_17_70');
## find the corresponding member
#my $family = $compara_dba->get_FamilyAdaptor()->fetch_by_stable_id('MF_00395');
#print "Family " . $family->stable_id() . "\n";
#for my $member (@{$family->get_all_Members()}) {
#    my $genome_db = $member->genome_db();
#    print $genome_db->name();
#    my ($member_dba) = @{$helper->get_by_name_exact($genome_db->name())};
#    if (defined $member_dba) {
#        my $gene = $member_dba->get_GeneAdaptor()->fetch_by_stable_id($member->stable_id());
#        print $member_dba->species() . " " . $gene->external_name . "\n";
#    }
#}
#To retrieve the genes belonging to a given family, filtering to a specific branch of the taxonomy:
#
#    use strict;
#use warnings;
#use Bio::EnsEMBL::LookUp;
#use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
#use Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor;
#
#print "Building helper\n";
#my $helper = Bio::EnsEMBL::LookUp->new();
#
#print "Connecting to taxonomy DB\n";
#my $node_adaptor = Bio::EnsEMBL::DBSQL::TaxonomyNodeAdaptor->new(Bio::EnsEMBL::DBSQL::DBAdaptor->new(-user    => 'anonymous',
#                                                                                                      -dbname  => 'ncbi_taxonomy',
#                                                                                                      -host    => 'mysql-eg-publicsql.ebi.ac.uk',
#                                                                                                      -port    => 4157,
#                                                                                                      -group   => 'taxonomy',
#                                                                                                     -species => 'ena'));
#
## find the taxids of all descendants of a specified node to use as a filter
#my $taxid = 1219;
#print "Finding taxonomy node for " . $taxid . "\n";
#my $root = $node_adaptor->fetch_by_taxon_id($taxid);
#my %taxids = map { $_->taxon_id() => 1 } @{$node_adaptor->fetch_descendants($root)};
#
## load compara adaptor
#my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-HOST => 'mysql-eg-publicsql.ebi.ac.uk', -USER => 'anonymous', -PORT => '4157', -DBNAME => 'ensembl_compara_bacteria_17_70');
## find the corresponding member
#my $family = $compara_dba->get_FamilyAdaptor()->fetch_by_stable_id('MF_00395');
#print "Family " . $family->stable_id() . "\n";
#for my $member (@{$family->get_all_Members()}) {
#    my $genome_db = $member->genome_db();
#  # filter by taxon from the calculated list
#    if (defined $taxids{$genome_db->taxon_id()}) {
#        my ($member_dba) = @{$helper->get_by_name_exact($genome_db->name())};
#        if (defined $member_dba) {
#            my $gene = $member_dba->get_GeneAdaptor()->fetch_by_stable_id($member->stable_id());
#            print $member_dba->species() . " " . $gene->external_name . "\n";
#        }
#    }
#}
#To retrieve the canonical peptides from genes belonging to a given family:
#
#    use strict;
#use warnings;
#use Bio::EnsEMBL::LookUp;
#use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
#use Bio::SeqIO;
#print "Building helper\n";
#my $helper = Bio::EnsEMBL::LookUp->new();
#
## load compara adaptor
#my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-HOST => 'mysql-eg-publicsql.ebi.ac.uk', -USER => 'anonymous', -PORT => '4157', -DBNAME => 'ensembl_compara_bacteria_17_70');
#
## find the corresponding member
#my $family  = $compara_dba->get_FamilyAdaptor()->fetch_by_stable_id('MF_00395');
#
## create a file to write to
#my $outfile = ">" . $family->stable_id . ".fa";
#my $seq_out = Bio::SeqIO->new(-file   => $outfile,
#                              -format => "fasta",);
#print "Writing family " . $family->stable_id() . " to $outfile\n";
#
## loop over members
#for my $member (@{$family->get_all_Members()}) {
#    my $genome_db = $member->genome_db();
#    my ($member_dba) = @{$helper->get_by_name_exact($genome_db->name())};
#    if (defined $member_dba) {
#        my $gene = $member_dba->get_GeneAdaptor()->fetch_by_stable_id($member->stable_id());
#        print "Writing sequence for " . $member->stable_id() . "\n";
#        my $s = $gene->canonical_transcript()->translate();
#        $seq_out->write_seq($s);
#    }
#}
