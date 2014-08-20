#!perl
# Copyright [2009-2014] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use Test::More;

BEGIN {
	use_ok( 'Bio::EnsEMBL::LookUp' );
}

my @arr = (1,2,2,3,4,5);
my @out = Bio::EnsEMBL::LookUp::uniq(@arr);
ok(scalar(@out)==5);
@arr = (1,2,3,4,5);
@out = Bio::EnsEMBL::LookUp::uniq(@arr);
ok(scalar(@out)==5);

@arr = qw/one two two three four five/;
@out = Bio::EnsEMBL::LookUp::uniq(@arr);
ok(scalar(@out)==5);
@arr = qw/one two three four five/;
@out = Bio::EnsEMBL::LookUp::uniq(@arr);
ok(scalar(@out)==5);

@arr = qw/one one two three four five five/;
@out = Bio::EnsEMBL::LookUp::uniq(@arr);
ok(scalar(@out)==5);

done_testing;
